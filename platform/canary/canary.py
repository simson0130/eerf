"""
EERF Canary — CDN + Origin 이중 경로 체크 (Python)
Runtime: syn-python-selenium-3.0

동작 방식:
  1. CloudFront URL과 Origin URL을 각각 health check
  2. x-canary-token 헤더를 전송하여 WAF AllowCanaryHealthCheck 규칙 통과
  3. CDN 실패 AND Origin 정상 → FAIL (CDN 경로 장애)
  4. CDN 실패 AND Origin 실패 → FAIL (인프라 전체 문제)
  5. CDN 정상 → PASS (Origin 상태 무관)
"""
import os
import urllib.request
import ssl


CANARY_TOKEN = os.environ.get("CANARY_TOKEN", "eerf-canary-secret-placeholder")
REQUEST_TIMEOUT = 10


def check_path(url, token):
    """주어진 URL에 x-canary-token 헤더와 함께 GET 요청"""
    req = urllib.request.Request(url, headers={"x-canary-token": token})
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        resp = urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT, context=ctx)
        return resp.status, resp.status < 400
    except Exception:
        return 0, False


def handler(event, context):
    cf_url = os.environ["CLOUDFRONT_URL"]
    origin_url = os.environ["ORIGIN_URL"]

    cf_status, cf_ok = check_path(cf_url, CANARY_TOKEN)
    origin_status, origin_ok = check_path(origin_url, CANARY_TOKEN)

    if not cf_ok and origin_ok:
        raise Exception(
            f"CDN path failed (status={cf_status}) while origin is healthy "
            f"(status={origin_status})"
        )
    if not cf_ok and not origin_ok:
        raise Exception(
            f"Both paths failed: CDN={cf_status}, Origin={origin_status}"
        )

    return {"cf_status": cf_status, "origin_status": origin_status}
