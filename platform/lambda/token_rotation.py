"""
EERF Canary Token Rotation Lambda

Rotates the canary token on a 90-day schedule:
1. Generate new random token
2. Update SSM Parameter (SecureString)
3. Update WAF AllowCanaryHealthCheck rules in all service accounts

Triggered by: EventBridge scheduled rule (every 90 days)
"""
import json
import os
import secrets
import logging
from datetime import datetime, timezone

import boto3

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

ssm = boto3.client("ssm")
sts = boto3.client("sts")
sns = boto3.client("sns")
s3 = boto3.client("s3")

NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")


def _generate_token(length=32):
    """Generate a cryptographically secure random token."""
    return secrets.token_urlsafe(length)


def _update_ssm_token(new_token):
    """Update SSM Parameter with new token value."""
    param_name = f"/{NAME_PREFIX}/canary/token"
    ssm.put_parameter(
        Name=param_name,
        Value=new_token,
        Type="SecureString",
        Overwrite=True,
    )
    logger.info(f"SSM Parameter {param_name} updated")


def _get_service_configs():
    """Load all service configs from SSM."""
    configs = []
    paginator = ssm.get_paginator("get_parameters_by_path")
    for page in paginator.paginate(Path=f"/{NAME_PREFIX}/services/", Recursive=False):
        for param in page["Parameters"]:
            configs.append(json.loads(param["Value"]))
    return configs


def _update_waf_canary_rule(service_config, new_token):
    """Update WAF AllowCanaryHealthCheck rule with new token in service account."""
    role_arn = service_config["cross_account_role_arn"]
    service_key = service_config.get("service_key", "unknown")

    resp = sts.assume_role(
        RoleArn=role_arn,
        RoleSessionName=f"eerf-token-rotation-{service_key}",
        DurationSeconds=900,
    )
    creds = resp["Credentials"]
    wafv2 = boto3.client(
        "wafv2",
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
    )

    web_acl_name = service_config["web_acl_name"]
    web_acl_id = service_config["web_acl_id"]

    current = wafv2.get_web_acl(Name=web_acl_name, Scope="REGIONAL", Id=web_acl_id)
    acl = current["WebACL"]
    lock_token = current["LockToken"]

    rules = acl["Rules"]
    updated = False
    for rule in rules:
        if rule.get("Name") == "AllowCanaryHealthCheck":
            stmt = rule.get("Statement", {})
            byte_match = stmt.get("ByteMatchStatement")
            if byte_match:
                byte_match["SearchString"] = new_token.encode("utf-8")
                updated = True
            break

    if updated:
        wafv2.update_web_acl(
            Name=web_acl_name,
            Scope="REGIONAL",
            Id=web_acl_id,
            DefaultAction=acl["DefaultAction"],
            Description=acl.get("Description", ""),
            Rules=rules,
            VisibilityConfig=acl["VisibilityConfig"],
            LockToken=lock_token,
        )
        logger.info(f"WAF updated for {service_key}")
    else:
        logger.warning(f"AllowCanaryHealthCheck rule not found in WAF for {service_key}")

    return updated


def _audit(result):
    """Write audit log to S3."""
    bucket = os.environ.get("AUDIT_BUCKET")
    if not bucket:
        return
    now = datetime.now(timezone.utc)
    key = f"audit/token-rotation/{now.strftime('%Y/%m/%d/%H%M%S')}-rotation.json"
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(result, indent=2, default=str).encode("utf-8"),
        ContentType="application/json",
    )


def handler(event, context):
    """Token rotation handler."""
    new_token = _generate_token()
    results = {
        "rotated_at": datetime.now(timezone.utc).isoformat(),
        "services": [],
    }

    # 1. Update SSM
    _update_ssm_token(new_token)

    # 2. Update WAF in each service account
    configs = _get_service_configs()
    for config in configs:
        service_key = config.get("service_key", "unknown")
        try:
            _update_waf_canary_rule(config, new_token)
            results["services"].append({"service_key": service_key, "status": "updated"})
        except Exception as e:
            logger.error(f"Failed to update WAF for {service_key}: {e}")
            results["services"].append(
                {"service_key": service_key, "status": "failed", "error": str(e)}
            )

    # 3. Audit + Notify
    _audit(results)
    topic = os.environ.get("SNS_TOPIC_ARN")
    if topic:
        sns.publish(
            TopicArn=topic,
            Subject="[EERF] Canary Token Rotated",
            Message=json.dumps(results, indent=2, default=str),
        )

    return results
