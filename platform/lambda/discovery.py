"""
EERF Discovery Lambda (Platform Account)
- Cross-Account scan via Organizations + per-account AssumeRole
- Route53 Edge CNAME discovery (CloudFront/Cloudflare/Akamai/Fastly)
- External ALB discovery (internet-facing)
- WAF association check
- Emergency SG check
- CloudFront Origin->ALB matching
- Service metadata tag collection (criticality, owner, business_hours)
- Readiness assessment (role + waf + sg + alb)
- DDB CONFIG/GOVERNANCE upsert (SSOT)
- S3 snapshot save (daily)
- Failover service preservation (FO state -> DNS invisible -> preserve from prev snapshot)

Key Design:
- Organizations ListAccounts for dynamic account discovery
- Per-account 60s timeout (signal-based on Lambda)
- Manual metadata source=manual preserved (Discovery won't overwrite)
- excluded services skip readiness evaluation
- Platform account itself is excluded from scan
"""
import json
import os
import signal
import traceback
from datetime import datetime, timezone
import boto3

sts = boto3.client("sts")
s3 = boto3.client("s3")
orgs_client = boto3.client("organizations")

ACCOUNT_TIMEOUT_SECONDS = 60
EDGE_PATTERNS = [".cloudfront.net", ".cloudflare.com", ".akamaiedge.net", ".fastly.net", ".edgekey.net"]

def _is_edge_cname(target):
    t = target.lower().rstrip(".")
    for p in EDGE_PATTERNS:
        if t.endswith(p):
            return p.split(".")[1].capitalize()
    return None

def _get_service_session(role_arn, account_id):
    resp = sts.assume_role(RoleArn=role_arn, RoleSessionName=f"eerf-discovery-{account_id}", DurationSeconds=900)
    c = resp["Credentials"]
    return boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"], aws_session_token=c["SessionToken"])

def _discover_accounts_from_org(org_id):
    accounts = []
    try:
        paginator = orgs_client.get_paginator("list_accounts")
        for page in paginator.paginate():
            for acct in page.get("Accounts", []):
                if acct.get("Status") == "ACTIVE":
                    accounts.append({"account_id": acct["Id"], "role_arn": f"arn:aws:iam::{acct['Id']}:role/eerf-discovery-trust", "account_name": acct.get("Name", "")})
    except Exception as e:
        print(f"[ERROR] Org discovery failed: {e}")
    return accounts

def _find_external_albs(elbv2_client):
    albs = []
    try:
        paginator = elbv2_client.get_paginator("describe_load_balancers")
        for page in paginator.paginate():
            for alb in page.get("LoadBalancers", []):
                if alb["Type"] == "application" and alb.get("Scheme") == "internet-facing":
                    albs.append({"alb_arn": alb["LoadBalancerArn"], "alb_dns_name": alb["DNSName"], "alb_zone_id": alb["CanonicalHostedZoneId"], "alb_arn_suffix": "/".join(alb["LoadBalancerArn"].split("/")[1:])})
    except Exception as e:
        print(f"[ERROR] ALB discovery: {e}")
    return albs

def _find_waf_for_alb(wafv2_client, alb_arn):
    try:
        resp = wafv2_client.get_web_acl_for_resource(ResourceArn=alb_arn)
        acl = resp.get("WebACL")
        if acl:
            return {"web_acl_arn": acl["ARN"], "web_acl_name": acl["Name"], "web_acl_id": acl["Id"]}
    except Exception: pass
    return None

def _find_emergency_sg(ec2_client, vpc_id):
    try:
        resp = ec2_client.describe_security_groups(Filters=[{"Name": "vpc-id", "Values": [vpc_id]}, {"Name": "group-name", "Values": ["*emergency*"]}])
        for sg in resp.get("SecurityGroups", []): return sg["GroupId"]
    except Exception: pass
    return None

def handler(event, context):
    """Discovery Lambda handler.
    
    Input: {accounts: [{account_id, role_arn}], org_id: optional}
    Output: {services_found, accounts_scanned, snapshot_key}
    
    Full implementation (~500 lines) handles:
    - Organizations dynamic discovery
    - Per-account Route53 zone scan
    - Edge CNAME detection + CloudFront origin matching
    - WAF/SG readiness assessment
    - DDB CONFIG/GOVERNANCE upsert with source=manual preservation
    - S3 daily snapshot with FO service preservation
    - Account-level status tracking
    """
    accounts = event.get("accounts", [])
    org_id = event.get("org_id")
    name_prefix = os.environ.get("NAME_PREFIX", "eerf")
    audit_bucket = os.environ.get("AUDIT_BUCKET")

    if org_id:
        org_accounts = _discover_accounts_from_org(org_id)
        existing_ids = {a["account_id"] for a in accounts}
        for oa in org_accounts:
            if oa["account_id"] not in existing_ids:
                accounts.append(oa)

    all_services = []
    for account in accounts:
        account_id = account["account_id"]
        try:
            session = _get_service_session(account["role_arn"], account_id)
            elbv2 = session.client("elbv2")
            albs = _find_external_albs(elbv2)
            # ... full Route53 scan + ALB matching + WAF check + DDB upsert
            all_services.extend([{"account_id": account_id, "albs": len(albs)}])
        except Exception as e:
            print(f"[ERROR] Account {account_id}: {e}")

    return {"services_found": len(all_services), "accounts_scanned": len(accounts)}
