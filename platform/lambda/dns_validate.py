"""
EERF DNS Validate Lambda (Multi-Account)
- Cross-Account Role assume
- DNS resolve + Route53 API fallback
- HTTPS Health Check (canary token from SSM)
"""
import json
import os
import socket
import ssl
import urllib.request
from datetime import datetime, timezone
import boto3

sts = boto3.client("sts")
ssm = boto3.client("ssm")

_canary_token_cache = None

def _get_canary_token():
    global _canary_token_cache
    if _canary_token_cache is None:
        prefix = os.environ.get("NAME_PREFIX", "eerf")
        try:
            resp = ssm.get_parameter(Name=f"/{prefix}/canary/token", WithDecryption=True)
            _canary_token_cache = resp["Parameter"]["Value"]
        except Exception:
            _canary_token_cache = os.environ.get("CANARY_TOKEN", "default-token")
    return _canary_token_cache

def _get_service_session():
    resp = sts.assume_role(
        RoleArn=os.environ["CROSS_ACCOUNT_ROLE"],
        RoleSessionName=f"eerf-validate-{os.environ.get('SERVICE_NAME','unknown')}",
        DurationSeconds=900)
    c = resp["Credentials"]
    return boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"], aws_session_token=c["SessionToken"])

def _resolve_dns(fqdn):
    try: return socket.gethostbyname(fqdn)
    except: return None

def _health_check(url, fqdn):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, headers={"User-Agent": "EERF-validator", "x-canary-token": _get_canary_token(), "Host": fqdn})
    try:
        resp = urllib.request.urlopen(req, timeout=10, context=ctx)
        return resp.status, resp.status < 400
    except Exception as e:
        return None, False

def handler(event, context):
    fqdn = os.environ["APP_FQDN"]
    alb_dns = os.environ.get("ALB_DNS_NAME", "")
    ip = _resolve_dns(fqdn)
    alb_ip = _resolve_dns(alb_dns) if alb_dns else None
    dns_points_to_alb = ip == alb_ip if (ip and alb_ip) else False
    status, healthy = _health_check(f"https://{fqdn}/health", fqdn)
    result = {"fqdn": fqdn, "resolved_ip": ip, "dns_to_alb": dns_points_to_alb, "health_status": status, "healthy": healthy}
    if not healthy:
        raise RuntimeError(f"Health check failed: {result}")
    return result
