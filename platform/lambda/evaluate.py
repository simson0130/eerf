"""
EERF Evaluate Lambda — Protection Readiness Assessment (weighted scoring)

Checks (weight sum = 100):
  1. Trust Role (15), 2. WAF (15), 3. Emergency SG (15), 4. ALB (15)
  5. Canary active (15), 6. Alarm (10), 7. SFN (10), 8. Drill recent (5)

Ready: score >= 95
Partial: 50-94
Not Ready: < 50

Phase 5c: auto-suspend (readiness lost) + auto-promote (approved->protected)
"""
import os
import logging
from datetime import datetime, timezone, timedelta
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")
REGION = os.environ.get("AWS_REGION", "ap-northeast-2")

WEIGHTS = {"trust_role": 15, "waf_attached": 15, "emergency_sg": 15, "alb_valid": 15, "canary_active": 15, "alarm_connected": 10, "sfn_exists": 10, "fo_drill_recent": 5}

def handler(event, context):
    from dal import ServiceRegistry
    registry = ServiceRegistry()
    service_key = event.get("service_key")
    if service_key:
        config = registry.get_config(service_key)
        services = [config] if config else []
    else:
        services = registry.list_by_type("CONFIG")
    if not services:
        return {"evaluated": 0}
    results, promoted, suspended = [], [], []
    for config in services:
        key = config.get("PK", "").replace("SERVICE#", "")
        ev = _evaluate_service(key, config)
        results.append(ev)
        _update_readiness(registry, key, ev)
        if _check_and_suspend(registry, key, ev): suspended.append(key)
        elif _check_and_promote(registry, key, ev): promoted.append(key)
    return {"evaluated": len(results), "promoted": promoted, "suspended": suspended}

def _evaluate_service(service_key, config):
    checks = {
        "trust_role": bool(config.get("cross_account_role_arn")),
        "waf_attached": bool(config.get("web_acl_arn")),
        "emergency_sg": bool(config.get("emergency_sg_id")),
        "alb_valid": bool(config.get("alb_arn")),
        "canary_active": _check_canary_active(service_key),
        "alarm_connected": _check_alarm_exists(service_key),
        "sfn_exists": _check_sfn_exists(service_key),
        "fo_drill_recent": _check_recent_drill(service_key),
    }
    total_weight = sum(WEIGHTS.values())
    earned = sum(WEIGHTS[k] for k, v in checks.items() if v and k in WEIGHTS)
    score = round((earned / total_weight) * 100)
    recommendation = "ready" if score >= 95 else ("partial" if score >= 50 else "not_ready")
    findings = _generate_findings(checks)
    return {"service_key": service_key, "score": score, "checks": checks, "recommendation": recommendation, "findings": findings, "evaluated_at": datetime.now(timezone.utc).isoformat()}

def _generate_findings(checks):
    findings = []
    mapping = {
        "trust_role": ("high", "Trust Role \uc5c6\uc74c \u2014 FO \ubd88\uac00"),
        "waf_attached": ("high", "WAF \ubbf8\uc5f0\uacb0 \u2014 Origin \ub178\ucd9c"),
        "emergency_sg": ("high", "Emergency SG \uc5c6\uc74c"),
        "alb_valid": ("high", "ALB \ubbf8\ud655\uc778"),
        "canary_active": ("medium", "Canary \ube44\ud65c\uc131"),
        "alarm_connected": ("medium", "Alarm \ubbf8\uc5f0\uacb0"),
        "sfn_exists": ("medium", "SFN \uc5c6\uc74c"),
        "fo_drill_recent": ("low", "30\uc77c \ub0b4 \ub9ac\ud5c8\uc124 \uc5c6\uc74c"),
    }
    for key, (sev, msg) in mapping.items():
        if not checks.get(key):
            findings.append({"severity": sev, "item": key, "message": msg})
    return findings

def _check_canary_active(sk):
    try:
        resp = boto3.client("synthetics", region_name=REGION).get_canary(Name=f"{NAME_PREFIX}-{sk}")
        return resp.get("Canary", {}).get("Status", {}).get("State") == "RUNNING"
    except Exception: return False

def _check_alarm_exists(sk):
    try:
        resp = boto3.client("cloudwatch", region_name=REGION).describe_alarms(AlarmNamePrefix=f"{NAME_PREFIX}-{sk}-", MaxRecords=1)
        return len(resp.get("MetricAlarms", [])) > 0
    except Exception: return False

def _check_sfn_exists(sk):
    try:
        account = boto3.client("sts").get_caller_identity()["Account"]
        boto3.client("stepfunctions", region_name=REGION).describe_state_machine(stateMachineArn=f"arn:aws:states:{REGION}:{account}:stateMachine:{NAME_PREFIX}-{sk}-failover")
        return True
    except Exception: return False

def _check_recent_drill(sk):
    try:
        table = boto3.resource("dynamodb").Table(os.environ.get("HISTORY_TABLE", "eerf-history"))
        from boto3.dynamodb.conditions import Key
        since = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
        resp = table.query(KeyConditionExpression=Key("PK").eq(f"SERVICE#{sk}") & Key("SK").gte(since), Limit=20)
        return any(i.get("new_state") == "failover" for i in resp.get("Items", []))
    except Exception: return False

def _update_readiness(registry, sk, ev):
    try:
        registry.table.update_item(
            Key={"PK": f"SERVICE#{sk}", "SK": "CONFIG"},
            UpdateExpression="SET readiness = :r",
            ExpressionAttributeValues={":r": {"score": ev["score"], "recommendation": ev["recommendation"], **{k: v for k, v in ev["checks"].items()}, "findings": ev["findings"], "evaluated_at": ev["evaluated_at"]}},
        )
    except Exception as e: logger.warning(f"readiness update failed: {e}")

def _check_and_suspend(registry, sk, ev):
    try:
        gov = registry.get_governance(sk)
        if not gov: return False
        state = gov.get("governance_state", "")
        checks = ev.get("checks", {})
        critical = [k for k in ("trust_role", "waf_attached", "emergency_sg", "alb_valid") if not checks.get(k)]
        if state in ("approved", "protected") and critical:
            registry.set_governance(sk, "suspended", operator_id="system (evaluate)", reason=f"readiness \ubbf8\ucda9\uc871: {critical}")
            return True
        if state == "suspended" and not critical:
            restore = gov.get("previous_state", "approved")
            registry.set_governance(sk, restore if restore in ("approved", "protected") else "approved", operator_id="system (evaluate)", reason="readiness \ubcf5\uad6c")
        return False
    except Exception: return False

def _check_and_promote(registry, sk, ev):
    try:
        gov = registry.get_governance(sk)
        if not gov or gov.get("governance_state") != "approved": return False
        checks = ev.get("checks", {})
        promote_keys = ("trust_role", "waf_attached", "emergency_sg", "alb_valid", "canary_active", "alarm_connected", "sfn_exists")
        if all(checks.get(k) for k in promote_keys) and ev.get("score", 0) >= 95:
            registry.set_governance(sk, "protected", operator_id="system (evaluate)", reason=f"\uc790\ub3d9 \uc2b9\uaca9: score={ev['score']}")
            return True
        return False
    except Exception: return False
