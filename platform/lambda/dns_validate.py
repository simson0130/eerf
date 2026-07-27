"""
EERF DNS Validate Lambda (Multi-Account)
- DDB CONFIG based service config
- Cross-Account Role assume (Route53 lookup)
- DNS resolve + HTTPS Health Check
"""
import json
import os
import socket
import ssl
import urllib.request
from datetime import datetime, timezone

import boto3

sts = None
ssm = None

def _get_sts():
    global sts
    if sts is None:
        sts = boto3.client("sts")
    return sts

def _get_ssm():
    global ssm
    if ssm is None:
        ssm = boto3.client("ssm")
    return ssm

_canary_token_cache = None

class ServiceConfigNotFound(Exception):
    pass

def _load_service_config(service_key: str) -> dict:
    from dal import ServiceRegistry
    registry = ServiceRegistry()
    config = registry.get_config(service_key)
    if not config:
        raise ServiceConfigNotFound(f"Service config not found: {service_key}")
    if "app_fqdn" not in config:
        config["app_fqdn"] = f"{config.get('app_subdomain', '')}.{config.get('domain_name', '')}"
    config["service_key"] = service_key
    return config

def _get_canary_token():
    global _canary_token_cache
    if _canary_token_cache is None:
        name_prefix = os.environ.get("NAME_PREFIX", "eerf")
        try:
            resp = _get_ssm().get_parameter(Name=f"/{name_prefix}/canary/token", WithDecryption=True)
            _canary_token_cache = resp["Parameter"]["Value"]
        except Exception:
            _canary_token_cache = os.environ.get("CANARY_TOKEN", "eerf-canary-default")
    return _canary_token_cache

def _get_service_session(role_arn: str, service_key: str):
    resp = _get_sts().assume_role(RoleArn=role_arn, RoleSessionName=f"eerf-validate-{service_key}", DurationSeconds=900)
    creds = resp["Credentials"]
    return boto3.Session(aws_access_key_id=creds["AccessKeyId"], aws_secret_access_key=creds["SecretAccessKey"], aws_session_token=creds["SessionToken"])

def _resolve_dns(app_fqdn, route53_client, hosted_zone_id):
    try:
        _, _, ips = socket.gethostbyname_ex(app_fqdn)
        return True, ips, f"https://{app_fqdn}/health"
    except Exception:
        pass
    if hosted_zone_id:
        try:
            records = route53_client.list_resource_record_sets(HostedZoneId=hosted_zone_id, StartRecordName=app_fqdn, StartRecordType="CNAME", MaxItems="1")
            for rr in records.get("ResourceRecordSets", []):
                if rr["Name"].rstrip(".") == app_fqdn.rstrip(".") and rr["Type"] == "CNAME":
                    target = rr["ResourceRecords"][0]["Value"]
                    return True, [target], f"https://{target}/health"
        except Exception:
            pass
    return False, [], ""

def _health_check(health_url, app_fqdn):
    req = urllib.request.Request(health_url, headers={"User-Agent": "EERF-dns-validator", "x-canary-token": _get_canary_token(), "Host": app_fqdn})
    verify_ssl = os.environ.get("EERF_VERIFY_SSL", "true").lower() != "false"
    ctx = ssl.create_default_context()
    if not verify_ssl:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
        return response.status, response.status == 200

def handler(event, context):
    service_key = event.get("service_key")
    if not service_key:
        raise ValueError("Missing 'service_key'")
    config = _load_service_config(service_key)
    app_fqdn = config["app_fqdn"]
    session = _get_service_session(config["cross_account_role_arn"], service_key)
    route53_client = session.client("route53")
    result = {"checkedAt": datetime.now(timezone.utc).isoformat(), "service": service_key, "appFqdn": app_fqdn, "dnsResolved": False, "healthy": False}
    resolved, targets, health_url = _resolve_dns(app_fqdn, route53_client, config.get("hosted_zone_id", ""))
    result["dnsResolved"] = resolved
    result["resolvedIps"] = targets
    result["healthUrl"] = health_url
    if not resolved:
        result["error"] = "DNS resolution failed"
        raise Exception(json.dumps(result))
    try:
        status, healthy = _health_check(health_url, app_fqdn)
        result["httpStatus"] = status
        result["healthy"] = healthy
    except Exception as e:
        result["error"] = f"Health check failed: {e}"
        raise Exception(json.dumps(result))
    if not result["healthy"]:
        raise Exception(json.dumps(result))
    return result
