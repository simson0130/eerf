"""
EERF Failover Lambda (Multi-Account)
- Cross-Account Role assume
- Route53 CNAME switch (CloudFront → ALB)
- WAF mode transition (COUNT → BLOCK)
- ALB Emergency SG attachment
- Audit logging + SNS notification

Code hardening:
- WAF LockToken retry (3 attempts)
- Audit logging failure handling
- DNS ResourceRecords validation
- ALB SG defensive check
"""
import json
import os
import time
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
sns = boto3.client("sns")
sts = boto3.client("sts")


def _get_service_session():
    role_arn = os.environ["CROSS_ACCOUNT_ROLE"]
    service_name = os.environ.get("SERVICE_NAME", "unknown")
    resp = sts.assume_role(RoleArn=role_arn, RoleSessionName=f"eerf-failover-{service_name}", DurationSeconds=900)
    creds = resp["Credentials"]
    return boto3.Session(aws_access_key_id=creds["AccessKeyId"], aws_secret_access_key=creds["SecretAccessKey"], aws_session_token=creds["SessionToken"])


def _check_idempotency(route53_client):
    zone_id = os.environ["HOSTED_ZONE_ID"]
    record_name = os.environ["APP_FQDN"]
    alb_dns = os.environ["ALB_DNS_NAME"].lower().rstrip(".")
    records = route53_client.list_resource_record_sets(HostedZoneId=zone_id, StartRecordName=record_name, StartRecordType="CNAME", MaxItems="1")
    for rr in records.get("ResourceRecordSets", []):
        if rr["Name"].rstrip(".") == record_name.rstrip(".") and rr["Type"] == "CNAME":
            resource_records = rr.get("ResourceRecords", [])
            if not resource_records:
                raise ValueError(f"DNS record {record_name} has no ResourceRecords")
            if resource_records[0]["Value"].lower().rstrip(".") == alb_dns:
                return {"action": "failover", "skipped": True, "reason": "Already in failover state"}
    return None


def _set_route53_to_alb(route53_client):
    change = {"Comment": "EERF failover", "Changes": [{"Action": "UPSERT", "ResourceRecordSet": {"Name": os.environ["APP_FQDN"], "Type": "CNAME", "TTL": 60, "ResourceRecords": [{"Value": os.environ["ALB_DNS_NAME"]}]}}]}
    return route53_client.change_resource_record_sets(HostedZoneId=os.environ["HOSTED_ZONE_ID"], ChangeBatch=change)["ChangeInfo"]["Id"]


def _set_waf_block(wafv2_client):
    """WAF BLOCK with LockToken retry (max 3)"""
    name, web_acl_id = os.environ["WEB_ACL_NAME"], os.environ["WEB_ACL_ID"]
    scope = os.environ.get("WEB_ACL_SCOPE", "REGIONAL")
    for attempt in range(3):
        try:
            cur = wafv2_client.get_web_acl(Name=name, Scope=scope, Id=web_acl_id)
            acl, lt = cur["WebACL"], cur["LockToken"]
            rules = []
            for r in acl["Rules"]:
                r = dict(r)
                if r.get("Name") in ("AllowCanaryHealthCheck", "RateBasedRule"):
                    rules.append(r); continue
                if "OverrideAction" in r: r["OverrideAction"] = {"None": {}}
                if "Action" in r: r["Action"] = {"Block": {}}
                rules.append(r)
            wafv2_client.update_web_acl(Name=name, Scope=scope, Id=web_acl_id, DefaultAction=acl["DefaultAction"], Description=acl.get("Description",""), Rules=rules, VisibilityConfig=acl["VisibilityConfig"], LockToken=lt)
            return
        except Exception as e:
            if "LockToken" in str(e) and attempt < 2: time.sleep(0.5); continue
            raise


def _attach_emergency_sg(elbv2_client):
    alb_arn, esg = os.environ["ALB_ARN"], os.environ["EMERGENCY_SG_ID"]
    desc = elbv2_client.describe_load_balancers(LoadBalancerArns=[alb_arn])
    sgs = desc["LoadBalancers"][0].get("SecurityGroups", [])
    if not sgs: raise RuntimeError(f"ALB {alb_arn} has no security groups")
    if esg not in sgs:
        elbv2_client.set_security_groups(LoadBalancerArn=alb_arn, SecurityGroups=sgs + [esg])


def _audit(event, result):
    bucket = os.environ["AUDIT_BUCKET"]
    service = os.environ.get("SERVICE_NAME", "unknown")
    key = f"{service}/{datetime.now(timezone.utc).strftime('%Y/%m/%d/%H%M%S')}-failover.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps({"timestamp": datetime.now(timezone.utc).isoformat(), "service": service, "event": event, "result": result}, indent=2, default=str).encode("utf-8"), ContentType="application/json")


def _notify(result):
    sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"], Subject=f"[EERF] Failover - {os.environ.get('SERVICE_NAME','unknown')}", Message=json.dumps(result, indent=2, default=str))


def handler(event, context):
    result = None
    try:
        session = _get_service_session()
        r53, waf, elb = session.client("route53"), session.client("wafv2"), session.client("elbv2")
        skip = _check_idempotency(r53)
        if skip: return skip
        rid = _set_route53_to_alb(r53)
        _set_waf_block(waf)
        _attach_emergency_sg(elb)
        result = {"action": "failover", "status": "success", "service": os.environ.get("SERVICE_NAME"), "route53ChangeId": rid, "wafMode": "block", "executedAt": datetime.now(timezone.utc).isoformat()}
    except Exception as e:
        result = {"action": "failover", "status": "failed", "error": str(e), "executedAt": datetime.now(timezone.utc).isoformat()}
    finally:
        try: _audit(event, result); _notify(result)
        except Exception as ae: print(f"[CRITICAL] Audit failed: {ae}")
    if result.get("status") == "failed": raise RuntimeError(result["error"])
    return result
