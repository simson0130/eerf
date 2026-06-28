"""
EERF Approval State Module

Manages approval state for discovered services.
States: Approved, Deferred, Pending_Approval, Excluded

Storage: approval-state.yaml in S3 (best-effort persistence)
Key format: "account_id:fqdn"
"""
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
import yaml

logger = logging.getLogger(__name__)
VALID_STATES = frozenset({"Approved", "Deferred", "Pending_Approval", "Excluded"})
ApprovalKey = str

class InvalidStateError(Exception): pass
class ApprovalStateError(Exception): pass

class ApprovalStateRecord:
    def __init__(self, status, operator_id, timestamp, reason=None):
        if status not in VALID_STATES:
            raise InvalidStateError(f"Invalid state '{status}'")
        self.status = status
        self.operator_id = operator_id
        self.timestamp = timestamp
        self.reason = reason

    def to_dict(self):
        d = {"status": self.status, "operator_id": self.operator_id, "timestamp": self.timestamp}
        if self.reason: d["reason"] = self.reason
        return d

def make_key(account_id, fqdn): return f"{account_id}:{fqdn}"
def parse_key(key):
    parts = key.split(":", 1)
    if len(parts) != 2: raise ApprovalStateError(f"Invalid key: {key}")
    return parts[0], parts[1]

class ApprovalStateConfig:
    def __init__(self, services=None):
        self._services = {}
        if services:
            for key, data in services.items():
                status = data.get("status", "")
                if status in VALID_STATES:
                    self._services[key] = ApprovalStateRecord(status, data.get("operator_id", "unknown"), data.get("timestamp", ""), data.get("reason"))

    def get_state(self, account_id, fqdn):
        return self._services.get(make_key(account_id, fqdn))

    def get_status(self, account_id, fqdn):
        r = self.get_state(account_id, fqdn)
        return r.status if r else None

    def set_state(self, account_id, fqdn, status, operator_id, reason=None, timestamp=None):
        if status not in VALID_STATES: raise InvalidStateError(f"Invalid: {status}")
        if not timestamp: timestamp = datetime.now(timezone.utc).isoformat()
        record = ApprovalStateRecord(status, operator_id, timestamp, reason)
        self._services[make_key(account_id, fqdn)] = record
        return record

    def assign_pending_approval(self, account_id, fqdn, operator_id="system", reason=None, timestamp=None):
        existing = self.get_state(account_id, fqdn)
        if existing: return existing
        return self.set_state(account_id, fqdn, "Pending_Approval", operator_id, reason or "Newly discovered", timestamp)

    def count_by_status(self):
        counts = {s: 0 for s in VALID_STATES}
        for r in self._services.values(): counts[r.status] += 1
        return counts

    def to_dict(self):
        return {"version": "1.0", "services": {k: v.to_dict() for k, v in self._services.items()}}

    def __len__(self): return len(self._services)
    def __contains__(self, key): return key in self._services

def parse_yaml(content):
    try: data = yaml.safe_load(content)
    except yaml.YAMLError as e: raise ApprovalStateError(f"YAML parse error: {e}")
    if not data: return ApprovalStateConfig()
    if not isinstance(data, dict): raise ApprovalStateError("Root must be mapping")
    services = data.get("services")
    if not services: return ApprovalStateConfig()
    if not isinstance(services, dict): raise ApprovalStateError("services must be mapping")
    return ApprovalStateConfig(services)

def load_from_s3(bucket, key="approval-state.yaml", s3_client=None):
    if not s3_client: s3_client = __import__('boto3').client('s3')
    try:
        resp = s3_client.get_object(Bucket=bucket, Key=key)
        return parse_yaml(resp["Body"].read().decode("utf-8"))
    except Exception as e:
        if "NoSuchKey" in str(e) or "404" in str(getattr(e, 'response', {}).get('Error', {}).get('Code', '')):
            return ApprovalStateConfig()
        logger.warning(f"Failed to load approval-state: {e}")
        return ApprovalStateConfig()

def save_to_s3(config, bucket, key="approval-state.yaml", s3_client=None):
    if not s3_client: s3_client = __import__('boto3').client('s3')
    try:
        content = yaml.dump(config.to_dict(), default_flow_style=False, allow_unicode=True)
        s3_client.put_object(Bucket=bucket, Key=key, Body=content.encode("utf-8"), ContentType="text/yaml")
        return True
    except Exception as e:
        logger.warning(f"Failed to save approval-state (best-effort): {e}")
        return False

def assign_pending_to_new_services(config, new_services, operator_id="system", timestamp=None):
    records = []
    for svc in new_services:
        aid, fqdn = str(svc.get("account_id", "")), str(svc.get("fqdn", ""))
        if aid and fqdn:
            records.append(config.assign_pending_approval(aid, fqdn, operator_id, timestamp=timestamp))
    return records
