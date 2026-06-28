"""
EERF Exclude Services Module

Parses exclude-services.yaml for Discovery/Diff Engine.
Services identified by composite key (account_id, fqdn).
"""
import os
from typing import Dict, List, Optional, Set, Tuple
import yaml

ExcludeKey = Tuple[str, str]

class ExcludeServicesConfig:
    def __init__(self, services: List[Dict[str, str]]):
        self._entries: Dict[ExcludeKey, Optional[str]] = {}
        for entry in services:
            key = (str(entry["account_id"]), str(entry["fqdn"]))
            self._entries[key] = entry.get("reason")

    @property
    def excluded_keys(self) -> Set[ExcludeKey]:
        return set(self._entries.keys())

    def is_excluded(self, account_id: str, fqdn: str) -> bool:
        return (str(account_id), str(fqdn)) in self._entries

    def get_reason(self, account_id: str, fqdn: str) -> Optional[str]:
        return self._entries.get((str(account_id), str(fqdn)))

    def __len__(self): return len(self._entries)
    def __contains__(self, key): return key in self._entries

class ExcludeServicesError(Exception): pass

def parse_yaml(content: str) -> ExcludeServicesConfig:
    try:
        data = yaml.safe_load(content)
    except yaml.YAMLError as e:
        raise ExcludeServicesError(f"Failed to parse YAML: {e}")
    if data is None: return ExcludeServicesConfig([])
    if not isinstance(data, dict): raise ExcludeServicesError("Root must be mapping")
    services = data.get("services")
    if services is None: return ExcludeServicesConfig([])
    if not isinstance(services, list): raise ExcludeServicesError("services must be list")
    return ExcludeServicesConfig(services)

def load_from_s3(bucket, key="exclude-services.yaml", s3_client=None):
    if s3_client is None: s3_client = __import__('boto3').client('s3')
    try:
        resp = s3_client.get_object(Bucket=bucket, Key=key)
        return parse_yaml(resp["Body"].read().decode("utf-8"))
    except Exception as e:
        if "NoSuchKey" in str(e) or "404" in str(getattr(e, 'response', {}).get('Error', {}).get('Code', '')):
            return ExcludeServicesConfig([])
        raise ExcludeServicesError(f"Failed to load: {e}")

def load(bucket=None, key="exclude-services.yaml", s3_client=None, file_path=None):
    if file_path:
        with open(file_path, "r") as f: return parse_yaml(f.read())
    elif bucket: return load_from_s3(bucket, key, s3_client)
    return ExcludeServicesConfig([])
