"""
EERF Portal API Lambda — Single Lambda, Router-based path dispatch.
27+ endpoints for Portal operations.

Endpoints:
  GET  /services              → All services (4-axis)
  GET  /services/search       → FQDN search
  GET  /services/{key}        → Service detail
  GET  /services/{key}/history → Change history
  GET  /services/{key}/executions → SFN executions
  GET  /services/{key}/alarms → CloudWatch alarms
  GET  /services/{key}/waf-rules → WAF rules + excluded
  POST /services/{key}/governance → Governance change
  POST /services/{key}/failback → Failback trigger
  PUT  /services/{key}/metadata → Metadata + FO options
  GET  /accounts              → Account scan status
  GET  /accounts/{id}/albs    → Cross-account ALBs
  GET  /accounts/{id}/wafs    → Cross-account WAFs
  GET  /accounts/{id}/sgs     → Cross-account SGs
  POST /accounts/{id}/waf-associate → WAF→ALB attach
  POST /accounts/{id}/create-sg → Emergency SG create
  GET  /dashboard/summary     → KPI dashboard
  GET  /history               → All history (days filter)
  GET  /evidence              → Evidence records
  GET  /reports               → Report presigned URLs
  GET  /executions/running    → Active SFN executions
  GET  /executions/recent     → Recent executions
  GET  /governance/executions → Governance pipeline history
  GET  /users                 → Cognito user list
  POST /users                 → Invite user
  PUT  /users/group           → Change user group
  DELETE /users               → Delete user
  POST /test/break            → FO test (dead origin sim)
  POST /test/restore          → Restore from test
  GET  /test/status/{key}     → Test status
  POST /discovery/run         → Manual discovery trigger
  POST /evaluate/run          → Manual evaluate trigger
  GET  /policy/rules          → Policy rules
  PUT  /policy/rules          → Update policy rules
  GET  /policy/override/{key} → Service policy override
  PUT  /policy/override/{key} → Update override
  POST /policy/evaluate       → Dry-run policy evaluation
"""
import json
import os
import re
import logging
from datetime import datetime, timedelta, timezone

import boto3

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")


# --- Input Validation ---

def _sanitize_input(value: str, max_length: int = 500) -> str:
    if not value: return ""
    value = value[:max_length]
    value = re.sub(r'<[^>]+>', '', value)
    return value.replace('\x00', '').strip()

def _validate_service_key(key: str) -> bool:
    if not key or len(key) > 100: return False
    return bool(re.match(r'^[a-zA-Z0-9\-_.]+$', key))

def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        },
        "body": json.dumps(body, default=str, ensure_ascii=False),
    }

def _get_operator(event):
    claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
    return claims.get("email", claims.get("sub", "unknown"))

def _get_groups(event):
    claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
    groups = claims.get("cognito:groups", "")
    return [g.strip() for g in groups.split(",") if g.strip()] if isinstance(groups, str) else (groups or [])

def _check_permission(event, required_level="ReadOnly"):
    groups = _get_groups(event)
    levels = {"Admin": 3, "Operator": 2, "ReadOnly": 1}
    required = levels.get(required_level, 1)
    user_level = max(levels.get(g, 0) for g in groups) if groups else 0
    return user_level >= required

def _extract_service_key(path: str, position: int = 2) -> str:
    parts = path.strip("/").split("/")
    if len(parts) > position:
        key = parts[position]
        if _validate_service_key(key): return key
    return ""

def _assume_role(account_id, role_name="eerf-discovery-trust"):
    sts_client = boto3.client("sts")
    resp = sts_client.assume_role(RoleArn=f"arn:aws:iam::{account_id}:role/{role_name}", RoleSessionName=f"eerf-api-{account_id}", DurationSeconds=900)
    c = resp["Credentials"]
    return {"aws_access_key_id": c["AccessKeyId"], "aws_secret_access_key": c["SecretAccessKey"], "aws_session_token": c["SessionToken"]}


# --- Core Handlers (27+ endpoints) ---
# Full implementation: ~1600 lines covering all endpoints above
# Key patterns:
#   - DAL (dal.py) for all DDB access
#   - Cross-account assume for infrastructure queries
#   - SFN start_execution for FO/FB/Discovery triggers
#   - Cognito AdminXxx for user management
#   - S3 presigned URLs for reports
#   - CloudWatch describe_alarms for status

def _list_services():
    from dal import ServiceRegistry
    registry = ServiceRegistry()
    configs = registry.list_by_type("CONFIG")
    gov_items = registry.list_by_type("GOVERNANCE")
    op_items = registry.list_by_type("OPERATION")
    health_items = registry.list_by_type("HEALTH")
    gov_map = {i["PK"]: i.get("governance_state", "unknown") for i in gov_items}
    op_map = {i["PK"]: i.get("operation_state", "unknown") for i in op_items}
    health_map = {i["PK"]: i.get("health_state", "unknown") for i in health_items}
    services = []
    for c in configs:
        pk = c["PK"]
        key = pk.replace("SERVICE#", "")
        fqdn = f"{c.get('app_subdomain', '')}.{c.get('domain_name', '')}"
        services.append({
            "service_key": key, "fqdn": fqdn,
            "account_id": c.get("account_id", ""),
            "account_name": c.get("account_name", ""),
            "environment": c.get("environment", ""),
            "governance": gov_map.get(pk, "unknown"),
            "operation": op_map.get(pk, "unknown"),
            "health": health_map.get(pk, "unknown"),
            "config": "ready" if c.get("readiness", {}).get("recommendation") == "ready" else "not_ready",
            "readiness": c.get("readiness"),
            "service_metadata": c.get("service_metadata"),
            "fo_options": c.get("fo_options"),
        })
    return _response(200, {"services": services})

def _get_service(service_key):
    if not _validate_service_key(service_key): return _response(400, {"error": "Invalid service_key"})
    from dal import ServiceRegistry
    registry = ServiceRegistry()
    full = registry.get_service_full(service_key)
    if not full: return _response(404, {"error": "Not found"})
    return _response(200, full)

def _update_service_metadata(service_key, body):
    if not service_key: return _response(400, {"error": "service_key required"})
    allowed_fields = {"criticality", "owner", "service_name", "business_hours"}
    fo_fields = {"fo_waf_switch", "fo_sg_attach", "waf_exclude_rules"}
    metadata_update = {k: v for k, v in body.items() if k in allowed_fields}
    fo_update = {k: v for k, v in body.items() if k in fo_fields}
    if not metadata_update and not fo_update:
        return _response(400, {"error": f"At least one field required: {allowed_fields | fo_fields}"})
    try:
        from dal import ServiceRegistry
        registry = ServiceRegistry()
        config = registry.get_config(service_key)
        if not config: return _response(404, {"error": f"Service not found: {service_key}"})
        update_expr_parts, expr_values = [], {}
        if metadata_update:
            existing = config.get("service_metadata", {}) or {}
            existing.update(metadata_update)
            existing["source"] = "manual"
            existing["updated_at"] = datetime.now(timezone.utc).isoformat()
            update_expr_parts.append("service_metadata = :m")
            expr_values[":m"] = existing
        if fo_update:
            existing_fo = config.get("fo_options", {"waf_switch": True, "sg_attach": True})
            if "fo_waf_switch" in fo_update:
                existing_fo["waf_switch"] = fo_update["fo_waf_switch"] in (True, "true", "True")
            if "fo_sg_attach" in fo_update:
                existing_fo["sg_attach"] = fo_update["fo_sg_attach"] in (True, "true", "True")
            if "waf_exclude_rules" in fo_update:
                rules = fo_update["waf_exclude_rules"]
                if isinstance(rules, list):
                    existing_fo["waf_exclude_rules"] = [str(r).strip() for r in rules if str(r).strip()]
                elif isinstance(rules, str):
                    existing_fo["waf_exclude_rules"] = [r.strip() for r in rules.split(",") if r.strip()]
                else:
                    existing_fo["waf_exclude_rules"] = []
            update_expr_parts.append("fo_options = :fo")
            expr_values[":fo"] = existing_fo
        registry.table.update_item(
            Key={"PK": f"SERVICE#{service_key}", "SK": "CONFIG"},
            UpdateExpression="SET " + ", ".join(update_expr_parts),
            ExpressionAttributeValues=expr_values,
        )
        return _response(200, {"status": "updated", "service_key": service_key})
    except Exception as e:
        return _response(500, {"error": str(e)})


# --- Router Setup ---
from routes.router import Router
_router = Router()

def _setup_routes():
    _router.get("/services", lambda e, q, **kw: _list_services())
    _router.get("/services/search", lambda e, q, **kw: _response(400, {"error": "fqdn required"}) if not q.get("fqdn") else _response(200, {"results": []}))
    _router.get("/services/{key}", lambda e, q, key="", **kw: _get_service(key))
    _router.put("/services/{key}/metadata", lambda e, q, key="", **kw: _update_service_metadata(key, json.loads(e.get("body", "{}"))), permission="Admin")
    # ... 37 routes total (see full source in private repo)

_setup_routes()

def handler(event, context):
    method = event.get("httpMethod", "GET")
    path = event.get("path", "")
    query = event.get("queryStringParameters") or {}
    if method == "OPTIONS": return _response(200, {})
    if path.startswith("/api"): path = path[4:]
    try:
        match = _router.match(method, path)
        if match:
            handler_fn, path_params, permission = match
            if permission != "ReadOnly" and not _check_permission(event, permission):
                return _response(403, {"error": f"{permission} required"})
            return handler_fn(event, query, **path_params)
        return _response(404, {"error": f"Not found: {method} {path}"})
    except Exception as e:
        logger.error(f"API error: {e}")
        return _response(500, {"error": str(e)})
