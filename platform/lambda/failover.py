"""
EERF Failover Lambda (Multi-Account)
- Cross-Account Role assume
- Route53 CNAME switch (CloudFront -> ALB)
- WAF mode transition (COUNT -> BLOCK)
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
    resp = sts.assume_role(
        RoleArn=os.environ["CROSS_ACCOUNT_ROLE"],
        RoleSessionName=f"eerf-failover-{os.environ.get('SERVICE_NAME', 'unknown')}",
        DurationSeconds=900,
    )
    c = resp["Credentials"]
    return boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"], aws_session_token=c["SessionToken"])


def _check_idempotency(r53):
    zone_id = os.environ["HOSTED_ZONE_ID"]
    record_name = os.environ["APP_FQDN"]
    alb_dns = os.environ["ALB_DNS_NAME"].lower().rstrip(".")
    records = r53.list_resource_record_sets(HostedZoneId=zone_id, StartRecordName=record_name, StartRecordType="CNAME", MaxItems="1")
    for rr in records.get("ResourceRecordSets", []):
        if rr["Name"].rstrip(".") == record_name.rstrip(".") and rr["Type"] == "CNAME":
            rrs = rr.get("ResourceRecords", [])
            if not rrs:
                raise ValueError(f"DNS record {record_name} has no ResourceRecords")
            if rrs[0]["Value"].lower().rstrip(".") == alb_dns:
                return {"action": "failover", "skipped": True, "reason": "Already in failover state"}
    return None


def _set_route53_to_alb(r53):
    res = r53.change_resource_record_sets(
        HostedZoneId=os.environ["HOSTED_ZONE_ID"],
        ChangeBatch={"Changes": [{"Action": "UPSERT", "ResourceRecordSet": {
            "Name": os.environ["APP_FQDN"], "Type": "CNAME", "TTL": 60,
            "ResourceRecords": [{"Value": os.environ["ALB_DNS_NAME"]}]}}]}
    )
    return res["ChangeInfo"]["Id"]


def _set_waf_block(waf):
    """WAF BLOCK with LockToken retry (max 3)"""
    name, wid, scope = os.environ["WEB_ACL_NAME"], os.environ["WEB_ACL_ID"], os.environ.get("WEB_ACL_SCOPE", "REGIONAL")
    for attempt in range(3):
        try:
            cur = waf.get_web_acl(Name=name, Scope=scope, Id=wid)
            acl, lt = cur["WebACL"], cur["LockToken"]
            rules = []
            for r in acl["Rules"]:
                rule = dict(r)
                if rule.get("Name") in ("AllowCanaryHealthCheck", "RateBasedRule"):
                    rules.append(rule); continue
                if "OverrideAction" in rule: rule["OverrideAction"] = {"None": {}}
                if "Action" in rule: rule["Action"] = {"Block": {}}
                rules.append(rule)
            waf.update_web_acl(Name=name, Scope=scope, Id=wid, DefaultAction=acl["DefaultAction"],
                Description=acl.get("Description",""), Rules=rules, VisibilityConfig=acl["VisibilityConfig"], LockToken=lt)
            return
        except Exception as e:
            if "LockToken" in str(e) and attempt < 2: time.sleep(0.5); continue
            raise


def _attach_emergency_sg(elb):
    alb_arn, esg = os.environ["ALB_ARN"], os.environ["EMERGENCY_SG_ID"]
    desc = elb.describe_load_balancers(LoadBalancerArns=[alb_arn])
    sgs = desc["LoadBalancers"][0].get("SecurityGroups", [])
    if not sgs: raise RuntimeError(f"ALB {alb_arn} has no security groups")
    if esg not in sgs:
        elb.set_security_groups(LoadBalancerArn=alb_arn, SecurityGroups=sgs + [esg])


def handler(event, context):
    result = None
    try:
        session = _get_service_session()
        r53, waf, elb = session.client("route53"), session.client("wafv2"), session.client("elbv2")
        skip = _check_idempotency(r53)
        if skip: return skip
        change_id = _set_route53_to_alb(r53)
        _set_waf_block(waf)
        _attach_emergency_sg(elb)
        result = {"action": "failover", "status": "success", "service": os.environ.get("SERVICE_NAME"), "route53ChangeId": change_id, "executedAt": datetime.now(timezone.utc).isoformat()}
    except Exception as e:
        result = {"action": "failover", "status": "failed", "error": str(e), "executedAt": datetime.now(timezone.utc).isoformat()}
    finally:
        try:
            svc = os.environ.get("SERVICE_NAME", "unknown")
            s3.put_object(Bucket=os.environ["AUDIT_BUCKET"], Key=f"{svc}/{datetime.now(timezone.utc).strftime('%Y/%m/%d/%H%M%S')}-failover.json", Body=json.dumps(result, default=str).encode())
            sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"], Subject=f"[EERF] Failover - {svc}", Message=json.dumps(result, default=str))
        except Exception as err:
            print(f"[CRITICAL] Audit failed: {err}")
    if result and result.get("status") == "failed": raise RuntimeError(result["error"])
    return result
