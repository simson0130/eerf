"""
EERF Failback Lambda (Multi-Account)
- Route53 CNAME restore (ALB -> CloudFront)
- WAF mode restore (BLOCK -> COUNT)
- Emergency SG detach
- Audit + Notify
"""
import json
import os
from datetime import datetime, timezone
import boto3

s3 = boto3.client("s3")
sns = boto3.client("sns")
sts = boto3.client("sts")

def _get_service_session():
    resp = sts.assume_role(
        RoleArn=os.environ["CROSS_ACCOUNT_ROLE"],
        RoleSessionName=f"eerf-failback-{os.environ.get('SERVICE_NAME','unknown')}",
        DurationSeconds=900)
    c = resp["Credentials"]
    return boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"], aws_session_token=c["SessionToken"])

def _set_route53_to_cdn(r53):
    r53.change_resource_record_sets(
        HostedZoneId=os.environ["HOSTED_ZONE_ID"],
        ChangeBatch={"Changes": [{"Action": "UPSERT", "ResourceRecordSet": {
            "Name": os.environ["APP_FQDN"], "Type": "CNAME", "TTL": 60,
            "ResourceRecords": [{"Value": os.environ["CLOUDFRONT_DNS_NAME"]}]}}]})

def _set_waf_count(waf):
    name, wid, scope = os.environ["WEB_ACL_NAME"], os.environ["WEB_ACL_ID"], os.environ.get("WEB_ACL_SCOPE", "REGIONAL")
    cur = waf.get_web_acl(Name=name, Scope=scope, Id=wid)
    acl, lt = cur["WebACL"], cur["LockToken"]
    rules = []
    for r in acl["Rules"]:
        rule = dict(r)
        if rule.get("Name") in ("AllowCanaryHealthCheck", "RateBasedRule"): rules.append(rule); continue
        if "OverrideAction" in rule: rule["OverrideAction"] = {"Count": {}}
        rules.append(rule)
    waf.update_web_acl(Name=name, Scope=scope, Id=wid, DefaultAction=acl["DefaultAction"],
        Description=acl.get("Description",""), Rules=rules, VisibilityConfig=acl["VisibilityConfig"], LockToken=lt)

def _detach_emergency_sg(elb):
    alb_arn, esg = os.environ["ALB_ARN"], os.environ["EMERGENCY_SG_ID"]
    desc = elb.describe_load_balancers(LoadBalancerArns=[alb_arn])
    sgs = desc["LoadBalancers"][0].get("SecurityGroups", [])
    if esg in sgs:
        elb.set_security_groups(LoadBalancerArn=alb_arn, SecurityGroups=[s for s in sgs if s != esg])

def handler(event, context):
    session = _get_service_session()
    _set_route53_to_cdn(session.client("route53"))
    _set_waf_count(session.client("wafv2"))
    _detach_emergency_sg(session.client("elbv2"))
    result = {"action": "failback", "status": "success", "service": os.environ.get("SERVICE_NAME"), "executedAt": datetime.now(timezone.utc).isoformat()}
    svc = os.environ.get("SERVICE_NAME", "unknown")
    s3.put_object(Bucket=os.environ["AUDIT_BUCKET"], Key=f"{svc}/{datetime.now(timezone.utc).strftime('%Y/%m/%d/%H%M%S')}-failback.json", Body=json.dumps(result, default=str).encode())
    sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"], Subject=f"[EERF] Failback - {svc}", Message=json.dumps(result, default=str))
    return result
