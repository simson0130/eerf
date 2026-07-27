"""
EERF Evidence Record Lambda
- SFN execution metadata collection
- MTTR calculation
- Source determination: alarm/drill/operator
- DDB History + S3 archive (Object Lock immutable)
"""
import json
import os
import time
from datetime import datetime, timezone
import boto3

_dynamodb = None
_s3 = None
_sfn = None

def _get_dynamodb():
    global _dynamodb
    if _dynamodb is None: _dynamodb = boto3.resource("dynamodb")
    return _dynamodb

def _get_s3():
    global _s3
    if _s3 is None: _s3 = boto3.client("s3")
    return _s3

def _get_sfn():
    global _sfn
    if _sfn is None: _sfn = boto3.client("stepfunctions")
    return _sfn

def _determine_source(event, service_key, action):
    explicit = event.get("source_type", "")
    if explicit in ("alarm", "drill", "operator"): return explicit
    try:
        table_name = os.environ.get("DYNAMODB_TABLE", "")
        if table_name:
            table = _get_dynamodb().Table(table_name)
            resp = table.get_item(Key={"PK": f"SERVICE#{service_key}", "SK": "OPERATION"}, ProjectionExpression="drill_active")
            if resp.get("Item", {}).get("drill_active"): return "drill"
    except Exception: pass
    return "alarm" if action == "failover" else "operator"

def handler(event, context):
    history_table = os.environ["HISTORY_TABLE"]
    audit_bucket = os.environ["AUDIT_BUCKET"]
    name_prefix = os.environ.get("NAME_PREFIX", "eerf")
    service_key = event.get("service_key", "unknown")
    action = event.get("action", "unknown")
    execution_arn = event.get("execution_arn", "")
    trigger_time = event.get("trigger_time", "")
    outcome = event.get("outcome", "unknown")
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    source = _determine_source(event, service_key, action)

    # MTTR
    mttr_seconds = None
    if trigger_time:
        try:
            trigger_dt = datetime.fromisoformat(trigger_time.replace("Z", "+00:00"))
            mttr_seconds = int((now - trigger_dt).total_seconds())
        except Exception: pass

    # DDB History
    try:
        table = _get_dynamodb().Table(history_table)
        table.put_item(Item={
            "PK": f"SERVICE#{service_key}", "SK": f"{now_iso}#EVIDENCE",
            "GSI1PK": "TYPE#EVIDENCE", "GSI1SK": now_iso,
            "action": action, "source": source, "outcome": outcome,
            "mttr_seconds": mttr_seconds or 0, "mttd_seconds": event.get("mttd_seconds") or 0,
            "trigger_time": trigger_time, "execution_arn": execution_arn,
            "before_state": event.get("before_state", {}), "after_state": event.get("after_state", {}),
            "affected_resources": event.get("affected_resources", []),
            "correlation_id": event.get("correlation_id", ""),
            "ttl": int(time.time()) + (365 * 86400),
        })
    except Exception as e:
        print(f"[EVIDENCE] DDB write failed: {e}")

    # S3 archive
    try:
        evidence_bucket = os.environ.get("EVIDENCE_BUCKET", audit_bucket)
        s3_key = f"evidence/{service_key}/{action}/{now.strftime('%Y/%m/%d/%H%M%S')}_{source}_{outcome}.json"
        evidence = {"service_key": service_key, "action": action, "source": source, "outcome": outcome,
            "timestamp": now_iso, "mttr_seconds": mttr_seconds, "before_state": event.get("before_state"),
            "after_state": event.get("after_state"), "affected_resources": event.get("affected_resources", [])}
        _get_s3().put_object(Bucket=evidence_bucket, Key=s3_key, Body=json.dumps(evidence, default=str), ContentType="application/json")
    except Exception as e:
        print(f"[EVIDENCE] S3 write failed: {e}")

    # Trigger health sync
    try:
        boto3.client("lambda").invoke(FunctionName=f"{name_prefix}-canary-health-sync", InvocationType="Event")
    except Exception: pass

    return {"service_key": service_key, "action": action, "source": source, "outcome": outcome, "mttr_seconds": mttr_seconds}
