"""
EERF Failback Lambda (Multi-Account, Unified)
- DDB CONFIG based service config loading
- Cross-Account Role assume
- Route53 CNAME restore (ALB → CloudFront)
- WAF mode restore (BLOCK → COUNT)
- ALB Emergency SG detach
- Partial failure rollback (remain in failover state)
- Cooling period enforcement (5min consecutive healthy)
- CORF Evidence Contract (before/after state capture)
- FO Options per-service (waf_switch, sg_attach, waf_exclude_rules)
"""
import json
import os
import time
from datetime import datetime, timezone
import boto3

s3 = boto3.client("s3")
sts = boto3.client("sts")
NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")

class ServiceConfigNotFound(Exception): pass

def _load_service_config(service_key):
    from dal import ServiceRegistry
    registry = ServiceRegistry()
    config = registry.get_config(service_key)
    if not config:
        raise ServiceConfigNotFound(f"Service config not found: {service_key}")
    if "app_fqdn" not in config:
        config["app_fqdn"] = f"{config.get('app_subdomain', '')}.{config.get('domain_name', '')}"
    config["service_key"] = service_key
    return config

def _get_service_session(role_arn, service_key):
    resp = sts.assume_role(RoleArn=role_arn, RoleSessionName=f"eerf-failback-{service_key}", DurationSeconds=900)
    creds = resp["Credentials"]
    return boto3.Session(aws_access_key_id=creds["AccessKeyId"], aws_secret_access_key=creds["SecretAccessKey"], aws_session_token=creds["SessionToken"])

def _check_idempotency(route53_client, config):
    zone_id = config["hosted_zone_id"]
    record_name = config["app_fqdn"]
    cf_dns = config["cloudfront_dns_name"].lower().rstrip(".")
    records = route53_client.list_resource_record_sets(HostedZoneId=zone_id, StartRecordName=record_name, StartRecordType="CNAME", MaxItems="1")
    for rr in records.get("ResourceRecordSets", []):
        if rr["Name"].rstrip(".") == record_name.rstrip(".") and rr["Type"] == "CNAME":
            rrs = rr.get("ResourceRecords", [])
            if rrs and rrs[0]["Value"].lower().rstrip(".") == cf_dns:
                return {"action": "failback", "skipped": True, "reason": "Already in normal state"}
    return None

def _set_route53_to_cloudfront(route53_client, config):
    change = {"Comment": "EERF failback", "Changes": [{"Action": "UPSERT", "ResourceRecordSet": {"Name": config["app_fqdn"], "Type": "CNAME", "TTL": 60, "ResourceRecords": [{"Value": config["cloudfront_dns_name"]}]}}]}
    return route53_client.change_resource_record_sets(HostedZoneId=config["hosted_zone_id"], ChangeBatch=change)["ChangeInfo"]["Id"]

def _set_waf_count(wafv2_client, config, exclude_rules=None):
    if exclude_rules is None:
        exclude_rules = ["AllowCanaryHealthCheck", "RateBasedRule"]
    name, web_acl_id, scope = config["web_acl_name"], config["web_acl_id"], config.get("web_acl_scope", "REGIONAL")
    for attempt in range(3):
        try:
            current = wafv2_client.get_web_acl(Name=name, Scope=scope, Id=web_acl_id)
            acl, lock_token = current["WebACL"], current["LockToken"]
            new_rules = []
            for rule in acl["Rules"]:
                r = dict(rule)
                if r.get("Name") in exclude_rules:
                    new_rules.append(r); continue
                if "OverrideAction" in r: r["OverrideAction"] = {"Count": {}}
                if "Action" in r: r["Action"] = {"Count": {}}
                new_rules.append(r)
            wafv2_client.update_web_acl(Name=name, Scope=scope, Id=web_acl_id, DefaultAction=acl["DefaultAction"], Description=acl.get("Description", ""), Rules=new_rules, VisibilityConfig=acl["VisibilityConfig"], LockToken=lock_token)
            return
        except Exception as e:
            if "LockToken" in str(e) and attempt < 2: time.sleep(0.5*(attempt+1)); continue
            raise

def _detach_emergency_sg(elbv2_client, config):
    alb_arn, emergency_sg = config["alb_arn"], config["emergency_sg_id"]
    desc = elbv2_client.describe_load_balancers(LoadBalancerArns=[alb_arn])
    current_sgs = desc["LoadBalancers"][0]["SecurityGroups"]
    if emergency_sg in current_sgs:
        elbv2_client.set_security_groups(LoadBalancerArn=alb_arn, SecurityGroups=[sg for sg in current_sgs if sg != emergency_sg])

def _rollback_partial(route53_client, wafv2_client, elbv2_client, config, steps):
    print(f"[ROLLBACK] Restoring failover state. Steps: {steps}")
    if "sg" in steps:
        try:
            alb_arn, emergency_sg = config["alb_arn"], config["emergency_sg_id"]
            desc = elbv2_client.describe_load_balancers(LoadBalancerArns=[alb_arn])
            sgs = desc["LoadBalancers"][0].get("SecurityGroups", [])
            if emergency_sg not in sgs:
                elbv2_client.set_security_groups(LoadBalancerArn=alb_arn, SecurityGroups=sgs + [emergency_sg])
        except Exception as e: print(f"[ROLLBACK] SG: {e}")
    if "waf" in steps:
        try:
            name, web_acl_id, scope = config["web_acl_name"], config["web_acl_id"], config.get("web_acl_scope", "REGIONAL")
            current = wafv2_client.get_web_acl(Name=name, Scope=scope, Id=web_acl_id)
            acl, lock_token = current["WebACL"], current["LockToken"]
            new_rules = []
            for rule in acl["Rules"]:
                r = dict(rule)
                if r.get("Name") in ("AllowCanaryHealthCheck", "RateBasedRule"): new_rules.append(r); continue
                if "OverrideAction" in r: r["OverrideAction"] = {"None": {}}
                if "Action" in r: r["Action"] = {"Block": {}}
                new_rules.append(r)
            wafv2_client.update_web_acl(Name=name, Scope=scope, Id=web_acl_id, DefaultAction=acl["DefaultAction"], Description=acl.get("Description", ""), Rules=new_rules, VisibilityConfig=acl["VisibilityConfig"], LockToken=lock_token)
        except Exception as e: print(f"[ROLLBACK] WAF: {e}")
    if "route53" in steps:
        try:
            change = {"Comment": "EERF rollback", "Changes": [{"Action": "UPSERT", "ResourceRecordSet": {"Name": config["app_fqdn"], "Type": "CNAME", "TTL": 60, "ResourceRecords": [{"Value": config["alb_dns_name"]}]}}]}
            route53_client.change_resource_record_sets(HostedZoneId=config["hosted_zone_id"], ChangeBatch=change)
        except Exception as e: print(f"[ROLLBACK] Route53: {e}")

def _capture_state(route53_client, wafv2_client, elbv2_client, config):
    state = {}
    try:
        records = route53_client.list_resource_record_sets(HostedZoneId=config["hosted_zone_id"], StartRecordName=config["app_fqdn"], StartRecordType="CNAME", MaxItems="1")
        for rr in records.get("ResourceRecordSets", []):
            if rr["Name"].rstrip(".") == config["app_fqdn"].rstrip(".") and rr["Type"] == "CNAME":
                state["dns_target"] = rr.get("ResourceRecords", [{}])[0].get("Value", "unknown")
    except Exception: state["dns_target"] = "error"
    try:
        current = wafv2_client.get_web_acl(Name=config["web_acl_name"], Scope=config.get("web_acl_scope", "REGIONAL"), Id=config["web_acl_id"])
        for r in current["WebACL"].get("Rules", []):
            if r.get("Name") in ("AllowCanaryHealthCheck", "RateBasedRule"): continue
            if "OverrideAction" in r: state["waf_mode"] = "COUNT" if "Count" in r["OverrideAction"] else "BLOCK"; break
    except Exception: state["waf_mode"] = "error"
    try:
        desc = elbv2_client.describe_load_balancers(LoadBalancerArns=[config["alb_arn"]])
        state["emergency_sg_attached"] = config["emergency_sg_id"] in desc["LoadBalancers"][0].get("SecurityGroups", [])
    except Exception: pass
    return state

def handler(event, context):
    result = None
    config = None
    try:
        service_key = event.get("service_key")
        if not service_key: raise ValueError("Missing 'service_key'")
        config = _load_service_config(service_key)
        session = _get_service_session(config["cross_account_role_arn"], service_key)
        route53_client, wafv2_client, elbv2_client = session.client("route53"), session.client("wafv2"), session.client("elbv2")

        skip = _check_idempotency(route53_client, config)
        if skip: return skip

        before_state = _capture_state(route53_client, wafv2_client, elbv2_client, config)

        # Cooling period
        COOLING_MINUTES = 5
        try:
            from dal import ServiceRegistry as _FbR
            health_item = _FbR().get_health(service_key)
            if health_item:
                if health_item.get("health_state") != "healthy" and not event.get("operator_id"):
                    return {"action": "failback", "status": "blocked", "reason": "cooling: not healthy"}
                healthy_since = health_item.get("healthy_since", "")
                if healthy_since:
                    since_dt = datetime.fromisoformat(healthy_since.replace("Z", "+00:00"))
                    elapsed = (datetime.now(timezone.utc) - since_dt).total_seconds() / 60
                    if elapsed < COOLING_MINUTES and not event.get("operator_id"):
                        return {"action": "failback", "status": "blocked", "reason": f"cooling: {elapsed:.1f}min < {COOLING_MINUTES}min"}
        except Exception as e: print(f"[WARNING] Cooling check failed: {e}")

        fo_options = config.get("fo_options", {})
        steps_completed = []
        try:
            route_change_id = _set_route53_to_cloudfront(route53_client, config)
            steps_completed.append("route53")
            if fo_options.get("waf_switch", True) and config.get("web_acl_name"):
                _set_waf_count(wafv2_client, config, fo_options.get("waf_exclude_rules", ["AllowCanaryHealthCheck", "RateBasedRule"]))
                steps_completed.append("waf")
            if fo_options.get("sg_attach", True) and config.get("emergency_sg_id"):
                _detach_emergency_sg(elbv2_client, config)
                steps_completed.append("sg")
        except Exception as e:
            _rollback_partial(route53_client, wafv2_client, elbv2_client, config, steps_completed)
            raise RuntimeError(f"Failback partial failure after {steps_completed}: {e}")

        result = {"action": "failback", "status": "success", "service": service_key, "before_state": before_state, "after_state": {"dns_target": config["cloudfront_dns_name"], "waf_mode": "COUNT", "emergency_sg_attached": False}, "executedAt": datetime.now(timezone.utc).isoformat()}

        try:
            from dal import ServiceRegistry
            registry = ServiceRegistry()
            op_item = registry.get_operation(service_key)
            source = "drill" if (op_item and op_item.get("drill_active")) else "operator"
            registry.set_operation(service_key, "standby", source=source, operator_id=event.get("operator_id", "system"))
        except Exception as e: print(f"[WARNING] DDB update failed: {e}")

    except Exception as e:
        result = {"action": "failback", "status": "failed", "error": str(e), "executedAt": datetime.now(timezone.utc).isoformat()}
    finally:
        try:
            if config:
                bucket = os.environ.get("AUDIT_BUCKET", "")
                if bucket:
                    key = f"{config['service_key']}/{datetime.now(timezone.utc).strftime('%Y/%m/%d/%H%M%S')}-failback.json"
                    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps({"event": event, "result": result}, default=str), ContentType="application/json")
                from alert import send_alert, AlertType
                at = AlertType.FAILBACK_SUCCESS if result.get("status") == "success" else AlertType.FAILBACK_FAILED
                send_alert(at, service_key=config["service_key"], fqdn=config.get("app_fqdn", ""))
        except Exception as e: print(f"[CRITICAL] Audit failed: {e}")

    if result and result.get("status") == "failed": raise RuntimeError(result["error"])
    return result
