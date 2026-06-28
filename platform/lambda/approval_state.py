"""
EERF Approval State Module (Shared)

Manages approval state tracking for discovered services.
States: Approved, Deferred, Pending_Approval, Excluded

Schema (approval-state.yaml):
    version: "1.0"
    services:
      "111111111111:app.example.com":
        status: Approved
        operator_id: "operator-1"
        timestamp: "2024-01-10T09:30:00Z"
        reason: "Production service - ready for protection"

Key functions:
  load_from_s3(bucket, key, client) - Load YAML from S3
  save_to_s3(config, bucket, key, client) - Save YAML to S3
  assign_pending_to_new_services(config, new_services) - Auto-assign Pending_Approval
  get_state(account_id, fqdn) - Lookup approval record

Requirements: 5.1-5.8
"""
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import yaml

logger = logging.getLogger(__name__)
VALID_STATES = frozenset({"Approved", "Deferred", "Pending_Approval", "Excluded"})


class ApprovalStateConfig:
    """In-memory approval state with load/save/query operations."""

    def __init__(self, data: Dict[str, Any]):
        self._data = data or {"version": "1.0", "services": {}}

    @property
    def services(self) -> Dict[str, Dict[str, Any]]:
        return self._data.get("services", {})

    def get_state(self, account_id: str, fqdn: str) -> Optional[Dict[str, Any]]:
        key = f"{account_id}:{fqdn}"
        return self.services.get(key)

    def set_state(self, account_id: str, fqdn: str, status: str, operator_id: str = "system", reason: str = ""):
        key = f"{account_id}:{fqdn}"
        self.services[key] = {
            "status": status,
            "operator_id": operator_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "reason": reason or f"State set to {status}",
        }

    def to_yaml(self) -> str:
        return yaml.dump(self._data, default_flow_style=False, allow_unicode=True)


def load_from_s3(bucket: str, key: str, client) -> ApprovalStateConfig:
    try:
        resp = client.get_object(Bucket=bucket, Key=key)
        data = yaml.safe_load(resp["Body"].read().decode("utf-8")) or {}
        return ApprovalStateConfig(data)
    except Exception as e:
        logger.warning(f"Failed to load {key} from s3://{bucket}/{key}: {e}")
        return ApprovalStateConfig({"version": "1.0", "services": {}})


def save_to_s3(config: ApprovalStateConfig, bucket: str, key: str, client):
    client.put_object(Bucket=bucket, Key=key, Body=config.to_yaml().encode("utf-8"), ContentType="text/yaml")


def assign_pending_to_new_services(config: ApprovalStateConfig, new_services: List[Dict[str, str]]):
    for svc in new_services:
        account_id = svc.get("account_id", "")
        fqdn = svc.get("fqdn", "")
        existing = config.get_state(account_id, fqdn)
        if not existing:
            config.set_state(account_id, fqdn, "Pending_Approval", reason="Newly discovered service")
