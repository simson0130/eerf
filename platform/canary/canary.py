"""
EERF Canary — Service + Backend Dual-Path Health Check
"""
import os
import urllib.request
import urllib.error
import ssl

import boto3

REQUEST_TIMEOUT = 10
_cached_token = None
_token_fetched_at = 0
_TOKEN_CACHE_TTL = 300


def _get_canary_token():
    global _cached_token, _token_fetched_at
    import time
    now = time.time()
    if _cached_token and (now - _token_fetched_at) < _TOKEN_CACHE_TTL:
        return _cached_token
    name_prefix = os.environ.get("NAME_PREFIX", "eerf")
    try:
        ssm = boto3.client("ssm")
        resp = ssm.get_parameter(Name=f"/{name_prefix}/canary/token", WithDecryption=True)
        _cached_token = resp["Parameter"]["Value"]
        _token_fetched_at = now
        return _cached_token
    except Exception:
        if _cached_token:
            return _cached_token
        return os.environ.get("CANARY_TOKEN", "eerf-canary-secret-2026")


def check_path(url, token):
    req = urllib.request.Request(url, headers={"x-canary-token": token})
    verify_ssl = os.environ.get("EERF_VERIFY_SSL", "true").lower() != "false"
    ctx = ssl.create_default_context()
    if not verify_ssl:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    try:
        resp = urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT, context=ctx)
        return resp.status, resp.status < 400
    except urllib.error.HTTPError as e:
        print(f"[ERROR] {url} \u2192 HTTP {e.code}: {e.reason}")
        return e.code, False
    except Exception as e:
        print(f"[ERROR] {url} \u2192 {type(e).__name__}: {e}")
        return 0, False


def handler(event, context):
    service_url = os.environ.get("SERVICE_URL") or os.environ.get("CLOUDFRONT_URL")
    backend_url = os.environ.get("BACKEND_URL") or os.environ.get("ORIGIN_URL")
    if not service_url or not backend_url:
        raise RuntimeError("SERVICE_URL and BACKEND_URL environment variables are required")

    token = _get_canary_token()
    name_prefix = os.environ.get("NAME_PREFIX", "eerf")

    svc_status, svc_ok = check_path(service_url, token)
    backend_status, backend_ok = check_path(backend_url, token)

    print(f"[CHECK] CDN: {service_url} \u2192 {svc_status} ({'OK' if svc_ok else 'FAIL'})")
    print(f"[CHECK] Origin: {backend_url} \u2192 {backend_status} ({'OK' if backend_ok else 'FAIL'})")

    # Custom Metrics
    try:
        cw = boto3.client("cloudwatch")
        svc_domain = service_url.split("://")[1].split(":")[0].split("/")[0]
        cw.put_metric_data(
            Namespace=f"{name_prefix}/Canary",
            MetricData=[
                {"MetricName": "CDNHealthy", "Value": 1.0 if svc_ok else 0.0, "Unit": "Count", "Dimensions": [{"Name": "Service", "Value": svc_domain}]},
                {"MetricName": "OriginHealthy", "Value": 1.0 if backend_ok else 0.0, "Unit": "Count", "Dimensions": [{"Name": "Service", "Value": svc_domain}]},
            ],
        )
    except Exception as metric_err:
        print(f"[WARNING] Custom metric publish failed: {metric_err}")

    # Verdict logic
    svc_domain = service_url.split("://")[1].split(":")[0].split("/")[0]

    if svc_ok:
        verdict = "PASS_HEALTHY"
        print(f"[VERDICT] {verdict} \u2014 CDN={svc_status}, Origin={backend_status}")
        return {"service": svc_domain, "verdict": verdict, "service_status": svc_status, "backend_status": backend_status}

    if not svc_ok and not backend_ok:
        verdict = "PASS_BOTH_FAILED"
        print(f"[VERDICT] {verdict} \u2014 CDN={svc_status}, Origin={backend_status}. Infra issue suspected.")
        return {"service": svc_domain, "verdict": verdict, "service_status": svc_status, "backend_status": backend_status}

    verdict = "FAIL_EDGE_ONLY"
    print(f"[VERDICT] {verdict} \u2014 CDN={svc_status}, Origin={backend_status}. Edge failure \u2192 FO trigger.")
    raise Exception(f"[{verdict}] service={svc_domain} CDN path failed (status={svc_status}) while Origin healthy (status={backend_status}).")
