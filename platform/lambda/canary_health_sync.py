"""
EERF Canary Health Sync Lambda - Canary Alarm state -> DDB HEALTH sync.
5-min interval. 500+ service scaling (batch describe 100ea).
"""
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")
cw = boto3.client("cloudwatch")

def handler(event, context):
    from dal import ServiceRegistry
    registry = ServiceRegistry()
    all_configs = registry.list_by_type("CONFIG")
    synced = 0
    skipped = 0
    service_alarm_map = {}
    for cfg in all_configs:
        service_key = cfg["PK"].replace("SERVICE#", "")
        service_alarm_map[f"{NAME_PREFIX}-{service_key}-cdn-path-failed"] = service_key
    alarm_names = list(service_alarm_map.keys())
    alarm_states = {}
    for i in range(0, len(alarm_names), 100):
        if context and context.get_remaining_time_in_millis() < 10000:
            break
        batch = alarm_names[i:i+100]
        try:
            resp = cw.describe_alarms(AlarmNames=batch, MaxRecords=100)
            for a in resp.get("MetricAlarms", []):
                alarm_states[a["AlarmName"]] = a.get("StateValue", "INSUFFICIENT_DATA")
        except Exception as e:
            logger.warning(f"Batch describe_alarms failed: {e}")
    for alarm_name, service_key in service_alarm_map.items():
        alarm_state = alarm_states.get(alarm_name)
        if alarm_state is None:
            skipped += 1
            continue
        health_state = "healthy" if alarm_state == "OK" else ("unhealthy" if alarm_state == "ALARM" else "unknown")
        current = registry.get_health(service_key)
        if current and current.get("health_state") == health_state:
            skipped += 1
            continue
        registry.set_health(service_key, health_state)
        synced += 1
    logger.info(f"Canary health sync: synced={synced}, skipped={skipped}")
    return {"synced": synced, "skipped": skipped}
