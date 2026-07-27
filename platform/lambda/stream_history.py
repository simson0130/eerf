"""
EERF Stream History Lambda — DynamoDB Streams → History Table
Tracks GOVERNANCE/OPERATION/HEALTH state changes.
History Table: PK=SERVICE#{key}, SK={timestamp}#{axis}
TTL: 180 days auto-delete.
"""
import os
import logging
from datetime import datetime, timezone, timedelta
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
HISTORY_TABLE = os.environ.get("HISTORY_TABLE", "eerf-history")
TRACKED_AXES = {"GOVERNANCE", "OPERATION", "HEALTH"}
STATE_FIELD_MAP = {"GOVERNANCE": "governance_state", "OPERATION": "operation_state", "HEALTH": "health_state"}
TTL_DAYS = 180
_table = None

def _get_history_table():
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(HISTORY_TABLE)
    return _table

def handler(event, context):
    table = _get_history_table()
    processed = skipped = 0
    for record in event.get("Records", []):
        event_name = record.get("eventName", "")
        if event_name == "REMOVE": skipped += 1; continue
        dynamodb_data = record.get("dynamodb", {})
        new_item = _deserialize(dynamodb_data.get("NewImage", {}))
        old_item = _deserialize(dynamodb_data.get("OldImage", {}))
        sk = new_item.get("SK", "")
        if sk not in TRACKED_AXES: skipped += 1; continue
        state_field = STATE_FIELD_MAP[sk]
        new_state = new_item.get(state_field, "")
        old_state = old_item.get(state_field, "") if old_item else ""
        if event_name == "MODIFY" and new_state == old_state: skipped += 1; continue
        service_key = new_item.get("PK", "").replace("SERVICE#", "")
        changed_at = new_item.get("updated_at", datetime.now(timezone.utc).isoformat())
        item = {
            "PK": f"SERVICE#{service_key}", "SK": f"{changed_at}#{sk}",
            "GSI1PK": f"HISTORY#{sk}", "GSI1SK": changed_at,
            "axis": sk, "previous_state": old_state, "new_state": new_state,
            "changed_at": changed_at, "event_type": event_name,
            "ttl": int((datetime.now(timezone.utc) + timedelta(days=TTL_DAYS)).timestamp()),
        }
        if new_item.get("operator_id"): item["operator_id"] = new_item["operator_id"]
        if new_item.get("reason"): item["reason"] = new_item["reason"]
        if new_item.get("source"): item["source"] = new_item["source"]
        try:
            table.put_item(Item=item)
            processed += 1
        except Exception as e:
            logger.error(f"History write failed: {service_key}/{sk}: {e}")
    logger.info(f"Stream history: processed={processed}, skipped={skipped}")
    return {"processed": processed, "skipped": skipped}

def _deserialize(dynamodb_json):
    if not dynamodb_json: return {}
    d = boto3.dynamodb.types.TypeDeserializer()
    return {k: d.deserialize(v) for k, v in dynamodb_json.items()}
