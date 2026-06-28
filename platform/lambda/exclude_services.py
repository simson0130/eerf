"""
EERF Exclude Services Module (Shared)

Parses exclude-services.yaml for Discovery and Diff Engine.

Schema:
    version: "1.0"
    services:
      - account_id: "333333333333"
        fqdn: "legacy.example.com"
        reason: "Optional reason"
"""
import os
from typing import Dict, List, Optional, Set, Tuple
import yaml

ExcludeKey = Tuple[str, str]


class ExcludeServicesConfig:
    """O(1) lookup for excluded services."""

    def __init__(self, services: List[Dict[str, str]]):
        self._excluded: Set[ExcludeKey] = set()
        self._reasons: Dict[ExcludeKey, str] = {}
        for svc in (services or []):
            key = (str(svc.get("account_id", "")), str(svc.get("fqdn", "")))
            self._excluded.add(key)
            if svc.get("reason"):
                self._reasons[key] = svc["reason"]

    def is_excluded(self, account_id: str, fqdn: str) -> bool:
        return (account_id, fqdn) in self._excluded

    def get_reason(self, account_id: str, fqdn: str) -> Optional[str]:
        return self._reasons.get((account_id, fqdn))

    @property
    def count(self) -> int:
        return len(self._excluded)


def load_from_s3(bucket: str, key: str, client) -> ExcludeServicesConfig:
    try:
        resp = client.get_object(Bucket=bucket, Key=key)
        data = yaml.safe_load(resp["Body"].read().decode("utf-8")) or {}
        return ExcludeServicesConfig(data.get("services", []))
    except Exception:
        return ExcludeServicesConfig([])
