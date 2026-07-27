"""
EERF Policy Decision Lambda
============================
CORF Policy Layer: evaluates recovery policy before execution.

Decision: ALLOW (start SFN) / DENY (notify only) / WAIT (approval needed)

Policy checks:
1. Governance state (approved/protected only)
2. Global kill-switch (SSM + DDB)
3. Blast radius (concurrent FO limit)
4. Criticality-based rules (tier1: WAIT in business hours)
5. Correlated failure detection (account 50%+)
6. Maintenance windows
"""
import json
import os
from datetime import datetime, timezone, timedelta

import boto3

NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")
REGION = os.environ.get("AWS_REGION", "ap-northeast-2")


def handler(event, context):
    service_key = event.get("service_key", "")
    if not service_key:
        detail = event.get("detail", {})
        alarm_name = detail.get("alarmName", "")
        if alarm_name.startswith(f"{NAME_PREFIX}-") and alarm_name.endswith("-cdn-path-failed"):
            service_key = alarm_name.replace(f"{NAME_PREFIX}-", "").replace("-cdn-path-failed", "")
    if not service_key:
        return {"decision": "DENY", "reason": "service_key_not_found"}

    now = datetime.now(timezone.utc).isoformat()
    decision, reason, details = _evaluate_policy(service_key)
    decision_record = {
        "service_key": service_key, "decision": decision, "reason": reason,
        "details": details, "policy_version": "v1.0", "evaluated_at": now,
    }
    print(f"[POLICY] {service_key}: {decision} \u2014 {reason}")

    if decision == "ALLOW":
        _start_failover_sfn(service_key, event, decision_record)
    elif decision == "DENY":
        _notify_denied(service_key, reason, details)
    elif decision == "WAIT":
        _notify_denied(service_key, f"WAIT: {reason}", details)

    return decision_record


def _evaluate_policy(service_key):
    details = {}
    criticality = "tier3"
    try:
        from dal import ServiceRegistry
        registry = ServiceRegistry()
        rules = registry.get_policy_rules()
        service_override = registry.get_service_policy_override(service_key) or {}

        # Governance
        gov_state = registry.get_governance_state(service_key)
        details["governance_state"] = gov_state
        if gov_state not in ("approved", "protected"):
            return ("DENY", f"governance_state={gov_state}", details)

        # Kill-switch
        if not rules.get("kill_switch", True):
            return ("DENY", "policy_kill_switch_disabled", details)
        try:
            ssm = boto3.client("ssm")
            param = ssm.get_parameter(Name=f"/{NAME_PREFIX}/global/fo-enabled")
            if param["Parameter"]["Value"].lower() == "false":
                return ("DENY", "global_kill_switch_active", details)
        except Exception:
            pass

        # Blast radius
        max_concurrent = int(rules.get("max_concurrent_failover", 3))
        from boto3.dynamodb.conditions import Key, Attr
        fo_resp = registry.table.query(
            IndexName="GSI1", KeyConditionExpression=Key("GSI1PK").eq("OPERATION"),
            FilterExpression=Attr("operation_state").eq("failover"), Select="COUNT",
        )
        current_fo = fo_resp.get("Count", 0)
        details["current_fo_count"] = current_fo
        if current_fo >= max_concurrent:
            return ("DENY", f"blast_radius_limit (current={current_fo}, max={max_concurrent})", details)

        # Criticality
        config = registry.get_config(service_key)
        metadata = config.get("service_metadata", {}) if config else {}
        criticality = service_override.get("criticality") or metadata.get("criticality") or "tier3"
        details["criticality"] = criticality

        criticality_rules = rules.get("criticality_rules", {})
        tier_rule = criticality_rules.get(criticality, {"default": "ALLOW"})
        biz_hours = metadata.get("business_hours") or rules.get("default_business_hours", "09-18")

        if criticality == "tier1" and _is_business_hours(biz_hours):
            action = tier_rule.get("business_hours", "WAIT")
            if action == "WAIT":
                return ("WAIT", "tier1_business_hours_requires_approval", details)

        # Correlated failure
        threshold = float(rules.get("correlated_failure_threshold", 0.5))
        if config and _is_correlated_failure(registry, service_key, config, threshold):
            details["correlated_failure"] = True
            corr_action = tier_rule.get("correlated", "WAIT")
            if corr_action == "WAIT":
                return ("WAIT", f"correlated_failure ({criticality})", details)

        # Maintenance
        if _in_maintenance_window(rules.get("maintenance_windows", [])):
            return ("DENY", "maintenance_window_active", details)

    except Exception as e:
        print(f"[POLICY] Evaluation failed, defaulting to ALLOW: {e}")
        details["error"] = str(e)

    return ("ALLOW", f"auto_recovery_permitted (criticality={criticality})", details)


def _is_business_hours(biz_hours_config) -> bool:
    KST = timezone(timedelta(hours=9))
    now_kst = datetime.now(KST)
    if biz_hours_config == "24x7":
        return False
    if now_kst.weekday() >= 5:
        return False
    if biz_hours_config and "-" in str(biz_hours_config):
        try:
            parts = str(biz_hours_config).split("-")
            return int(parts[0]) <= now_kst.hour < int(parts[1])
        except Exception:
            pass
    return 9 <= now_kst.hour < 18


def _in_maintenance_window(windows) -> bool:
    if not windows:
        return False
    KST = timezone(timedelta(hours=9))
    now_kst = datetime.now(KST)
    day_map = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}
    for w in windows:
        try:
            target_day = day_map.get(w.get("day", "").lower())
            if target_day is None or now_kst.weekday() != target_day:
                continue
            start_h = int(w.get("start", "0").split(":")[0])
            end_h = int(w.get("end", "0").split(":")[0])
            if start_h <= now_kst.hour < end_h:
                return True
        except Exception:
            continue
    return False


def _is_correlated_failure(registry, service_key, config, threshold=0.5) -> bool:
    try:
        account_id = config.get("account_id", "")
        if not account_id:
            return False
        from boto3.dynamodb.conditions import Key
        health_resp = registry.table.query(
            IndexName="GSI2", KeyConditionExpression=Key("GSI2PK").eq(f"ACCOUNT#{account_id}"),
        )
        health_items = [i for i in health_resp.get("Items", []) if i.get("SK") == "HEALTH"]
        if len(health_items) <= 1:
            return False
        unhealthy = sum(1 for h in health_items if h.get("health_state") == "unhealthy")
        return (unhealthy / len(health_items)) >= threshold
    except Exception:
        return False


def _start_failover_sfn(service_key, original_event, decision_record):
    try:
        sfn = boto3.client("stepfunctions")
        account_id = boto3.client("sts").get_caller_identity()["Account"]
        sfn_arn = f"arn:aws:states:{REGION}:{account_id}:stateMachine:{NAME_PREFIX}-{service_key}-failover"
        sfn_input = {
            "service_key": service_key, "source_type": "alarm",
            "operator_id": "system (policy: auto)", "policy_approved": True,
        }
        resp = sfn.start_execution(stateMachineArn=sfn_arn, input=json.dumps(sfn_input, default=str))
        print(f"[POLICY] SFN started: {resp['executionArn']}")
    except Exception as e:
        print(f"[POLICY] Failed to start SFN: {e}")
        _notify_denied(service_key, f"sfn_start_failed: {e}", {})


def _notify_denied(service_key, reason, details):
    try:
        from alert import send_alert, AlertType
        send_alert(AlertType.SFN_FAILED, service_key=service_key, details=f"[POLICY] {reason}")
    except Exception as e:
        print(f"[POLICY] Notify failed: {e}")
