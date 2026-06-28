"""
EERF DNS Validate Lambda (Multi-Account)
- DNS resolve (OS resolver + Route53 API fallback)
- HTTPS Health Check with x-canary-token header
- Canary token loaded from SSM Parameter Store
- Raises exception on failure → Step Functions retry/rollback
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


def _get_canary_token():
    """Load canary token from SSM (cached)."""
    name_prefix = os.environ.get("NAME_PREFIX", "eerf")
    resp = ssm.get_parameter(Name=f"/{name_prefix}/canary/token", WithDecryption=True)
    return resp["Parameter"]["Value"]


# Full implementation: ~150 lines
# Key functions:
#   _resolve_dns(fqdn) - OS + Route53 fallback
#   _health_check(fqdn, token) - HTTPS GET /health
#   handler(event, context) - validates DNS + health, raises on failure
