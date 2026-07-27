"""
EERF Data Access Layer (DAL) — DynamoDB Service Registry

Single Table Design:
  PK: SERVICE#{service_key}
  SK: CONFIG | GOVERNANCE | OPERATION | HEALTH

GSI1: 아이템 타입별 전체 조회 (GSI1PK=타입, GSI1SK=SERVICE#{key})
GSI2: 계정별 조회 (GSI2PK=ACCOUNT#{id}, GSI2SK=SERVICE#{key})

4-Axis Model:
  CONFIG     : 인프라 사실 + Readiness (Discovery 결과)
  GOVERNANCE : 관리 의사결정 (discovered/pending/approved/deferred/excluded)
  OPERATION  : 현재 구성 모드 (standby/failover/restoring)
  HEALTH     : 실시간 건강성 (healthy/degraded/unhealthy/unknown)

Usage:
  from dal import ServiceRegistry
  registry = ServiceRegistry()
  config = registry.get_config("app-srv1-6693")
  registry.set_operation("app-srv1-6693", "failover")
"""
import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import boto3
from boto3.dynamodb.conditions import Key, Attr

_table = None


def _get_table():
    global _table
    if _table is None:
        name_prefix = os.environ.get("NAME_PREFIX", "eerf")
        table_name = os.environ.get("DYNAMODB_TABLE", f"{name_prefix}-services")
        dynamodb = boto3.resource("dynamodb")
        _table = dynamodb.Table(table_name)
    return _table


class ServiceRegistry:
    """EERF Service Registry — DynamoDB 4-Axis Model."""

    def __init__(self, table=None):
        self.table = table or _get_table()

    def get_config(self, service_key: str) -> Optional[Dict[str, Any]]:
        resp = self.table.get_item(Key={"PK": f"SERVICE#{service_key}", "SK": "CONFIG"})
        return resp.get("Item")

    def put_config(self, service_key: str, config: Dict[str, Any]) -> None:
        existing = self.get_config(service_key)
        if existing:
            existing_meta = existing.get("service_metadata", {})
            if existing_meta and existing_meta.get("source") == "manual":
                config["service_metadata"] = existing_meta
        item = {
            "PK": f"SERVICE#{service_key}", "SK": "CONFIG",
            "GSI1PK": "CONFIG", "GSI1SK": f"SERVICE#{service_key}",
            "GSI2PK": f"ACCOUNT#{config.get('account_id', '')}",
            "GSI2SK": f"SERVICE#{service_key}",
            "updated_at": datetime.now(timezone.utc).isoformat(),
            **config,
        }
        self.table.put_item(Item=item)
        readiness = config.get("readiness", {})
        if isinstance(readiness, dict) and readiness.get("recommendation") == "excluded":
            return
        if not self.get_operation(service_key):
            self.set_operation(service_key, "standby")
        if not self.get_health(service_key):
            self.set_health(service_key, "unknown")

    def get_governance(self, service_key: str) -> Optional[Dict[str, Any]]:
        resp = self.table.get_item(Key={"PK": f"SERVICE#{service_key}", "SK": "GOVERNANCE"})
        return resp.get("Item")

    def get_governance_state(self, service_key: str) -> str:
        gov = self.get_governance(service_key)
        return gov.get("governance_state", "unknown") if gov else "unknown"

    def set_governance(self, service_key: str, governance_state: str, operator_id: str = "", reason: str = "", account_id: str = "", fqdn: str = "") -> None:
        now = datetime.now(timezone.utc).isoformat()
        existing = self.get_governance(service_key)
        previous_state = existing.get("governance_state", "") if existing else ""
        created_at = existing.get("created_at", now) if existing else now
        current_version = int(existing.get("version", 0)) if existing else 0
        item = {
            "PK": f"SERVICE#{service_key}", "SK": "GOVERNANCE",
            "GSI1PK": "GOVERNANCE", "GSI1SK": f"SERVICE#{service_key}",
            "governance_state": governance_state, "previous_state": previous_state,
            "operator_id": operator_id, "reason": reason,
            "created_at": created_at, "updated_at": now, "version": current_version + 1,
        }
        if account_id:
            item["account_id"] = account_id
            item["GSI2PK"] = f"ACCOUNT#{account_id}"
            item["GSI2SK"] = f"SERVICE#{service_key}"
        if fqdn:
            item["fqdn"] = fqdn
        if existing:
            try:
                self.table.put_item(
                    Item=item,
                    ConditionExpression="version = :expected" if current_version > 0 else "attribute_not_exists(version) OR version = :zero",
                    ExpressionAttributeValues={":expected": current_version} if current_version > 0 else {":zero": 0},
                )
            except self.table.meta.client.exceptions.ConditionalCheckFailedException:
                raise RuntimeError(f"Concurrent modification detected for {service_key} GOVERNANCE.")
        else:
            self.table.put_item(Item=item)

    def get_operation(self, service_key: str) -> Optional[Dict[str, Any]]:
        resp = self.table.get_item(Key={"PK": f"SERVICE#{service_key}", "SK": "OPERATION"})
        return resp.get("Item")

    def get_operation_state(self, service_key: str) -> str:
        op = self.get_operation(service_key)
        return op.get("operation_state", "unknown") if op else "unknown"

    def set_operation(self, service_key: str, operation_state: str, **kwargs) -> None:
        now = datetime.now(timezone.utc).isoformat()
        existing = self.get_operation(service_key)
        previous_state = existing.get("operation_state", "") if existing else ""
        created_at = existing.get("created_at", now) if existing else now
        drill_active = existing.get("drill_active", False) if existing else False
        item = {
            "PK": f"SERVICE#{service_key}", "SK": "OPERATION",
            "GSI1PK": "OPERATION", "GSI1SK": f"SERVICE#{service_key}",
            "operation_state": operation_state, "previous_state": previous_state,
            "created_at": created_at, "updated_at": now, "drill_active": drill_active,
        }
        if operation_state == "failover":
            item["last_failover_at"] = now
        elif operation_state == "standby":
            item["last_failback_at"] = now
            item["drill_active"] = False
        item.update(kwargs)
        self.table.put_item(Item=item)

    def get_health(self, service_key: str) -> Optional[Dict[str, Any]]:
        resp = self.table.get_item(Key={"PK": f"SERVICE#{service_key}", "SK": "HEALTH"})
        return resp.get("Item")

    def get_health_state(self, service_key: str) -> str:
        health = self.get_health(service_key)
        return health.get("health_state", "unknown") if health else "unknown"

    def set_health(self, service_key: str, health_state: str, consecutive_failures: int = 0, **kwargs) -> None:
        now = datetime.now(timezone.utc).isoformat()
        existing = self.get_health(service_key)
        previous_state = existing.get("health_state", "") if existing else ""
        created_at = existing.get("created_at", now) if existing else now
        if health_state == "healthy" and previous_state != "healthy":
            healthy_since = now
        elif health_state == "healthy" and existing:
            healthy_since = existing.get("healthy_since", now)
        else:
            healthy_since = ""
        item = {
            "PK": f"SERVICE#{service_key}", "SK": "HEALTH",
            "GSI1PK": "HEALTH", "GSI1SK": f"SERVICE#{service_key}",
            "health_state": health_state, "previous_state": previous_state,
            "consecutive_failures": consecutive_failures,
            "healthy_since": healthy_since, "created_at": created_at,
            "last_check_at": now, "updated_at": now,
        }
        item.update(kwargs)
        self.table.put_item(Item=item)

    def list_by_type(self, item_type: str) -> List[Dict[str, Any]]:
        items = []
        params = {"IndexName": "GSI1", "KeyConditionExpression": Key("GSI1PK").eq(item_type)}
        while True:
            resp = self.table.query(**params)
            items.extend(resp.get("Items", []))
            if "LastEvaluatedKey" not in resp:
                break
            params["ExclusiveStartKey"] = resp["LastEvaluatedKey"]
        return items

    def list_by_account(self, account_id: str) -> List[Dict[str, Any]]:
        resp = self.table.query(IndexName="GSI2", KeyConditionExpression=Key("GSI2PK").eq(f"ACCOUNT#{account_id}"))
        return resp.get("Items", [])

    def list_failover_services(self) -> List[Dict[str, Any]]:
        resp = self.table.query(
            IndexName="GSI1", KeyConditionExpression=Key("GSI1PK").eq("OPERATION"),
            FilterExpression=Attr("operation_state").eq("failover"),
        )
        return resp.get("Items", [])

    def get_all_services(self) -> List[Dict[str, Any]]:
        return self.list_by_type("CONFIG")

    def get_service_full(self, service_key: str) -> Dict[str, Any]:
        resp = self.table.query(KeyConditionExpression=Key("PK").eq(f"SERVICE#{service_key}"))
        result = {}
        for item in resp.get("Items", []):
            result[item.get("SK", "").lower()] = item
        return result

    # --- POLICY ---
    _DEFAULT_POLICY = {
        "kill_switch": True, "max_concurrent_failover": 3,
        "correlated_failure_threshold": 0.5,
        "criticality_rules": {
            "tier1": {"business_hours": "WAIT", "off_hours": "ALLOW", "correlated": "WAIT"},
            "tier2": {"business_hours": "ALLOW", "off_hours": "ALLOW", "correlated": "WAIT"},
            "tier3": {"default": "ALLOW"},
        },
        "maintenance_windows": [], "default_business_hours": "09-18",
    }

    def get_policy_rules(self) -> Dict[str, Any]:
        resp = self.table.get_item(Key={"PK": "POLICY#global", "SK": "RULES"})
        item = resp.get("Item")
        if item and "rules" in item:
            rules = item["rules"]
            return json.loads(rules) if isinstance(rules, str) else rules
        return self._DEFAULT_POLICY.copy()

    def put_policy_rules(self, rules: Dict[str, Any], operator_id: str = "") -> None:
        now = datetime.now(timezone.utc).isoformat()
        existing = self.table.get_item(Key={"PK": "POLICY#global", "SK": "RULES"}).get("Item")
        current_version = int(existing.get("version", 0)) if existing else 0
        item = {
            "PK": "POLICY#global", "SK": "RULES", "GSI1PK": "POLICY", "GSI1SK": "RULES",
            "rules": json.dumps(rules, default=str),
            "version": current_version + 1, "updated_at": now, "updated_by": operator_id,
        }
        self.table.put_item(Item=item)

    def get_service_policy_override(self, service_key: str) -> Optional[Dict[str, Any]]:
        resp = self.table.get_item(Key={"PK": f"POLICY#{service_key}", "SK": "OVERRIDE"})
        item = resp.get("Item")
        if item:
            override = item.get("override", {})
            return json.loads(override) if isinstance(override, str) else override
        return None

    def put_service_policy_override(self, service_key: str, override: Dict[str, Any], operator_id: str = "") -> None:
        now = datetime.now(timezone.utc).isoformat()
        item = {
            "PK": f"POLICY#{service_key}", "SK": "OVERRIDE",
            "GSI1PK": "POLICY", "GSI1SK": f"OVERRIDE#{service_key}",
            "override": json.dumps(override, default=str),
            "updated_at": now, "updated_by": operator_id,
        }
        self.table.put_item(Item=item)
