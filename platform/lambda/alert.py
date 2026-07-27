"""
EERF Unified Alert Module — 19 AlertTypes, SNS delivery.
Subject/Body format standardized across all Lambdas.

Usage:
  from alert import send_alert, AlertType
  send_alert(AlertType.FAILOVER_SUCCESS, service_key="app-srv1-6693", fqdn="app.srv1.example.com")
"""
import os
import logging
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Optional
import boto3

logger = logging.getLogger(__name__)
_sns_client = None

def _get_sns_client():
    global _sns_client
    if _sns_client is None: _sns_client = boto3.client("sns")
    return _sns_client

def _kst_now() -> str:
    return (datetime.now(timezone.utc) + timedelta(hours=9)).strftime("%Y-%m-%d %H:%M:%S")

class AlertType(Enum):
    FAILOVER_SUCCESS = "failover_success"
    FAILOVER_ROLLBACK = "failover_rollback"
    FAILBACK_SUCCESS = "failback_success"
    FAILBACK_FAILED = "failback_failed"
    HEALTH_UNHEALTHY = "health_unhealthy"
    HEALTH_RECOVERED = "health_recovered"
    REPORT_CHANGES = "report_changes"
    REPORT_NO_CHANGES = "report_no_changes"
    ONBOARDING_NEEDED = "onboarding_needed"
    GOVERNANCE_APPROVED = "governance_approved"
    GOVERNANCE_DEFERRED = "governance_deferred"
    GOVERNANCE_EXCLUDED = "governance_excluded"
    GOVERNANCE_REOPENED = "governance_reopened"
    GOVERNANCE_SUSPENDED = "governance_suspended"
    SFN_FAILED = "sfn_failed"
    PIPELINE_ERROR = "pipeline_error"
    TOKEN_ROTATED = "token_rotated"
    TOKEN_ROTATION_FAILED = "token_rotation_failed"
    HISTORY_WRITE_FAILED = "history_write_failed"

_SUBJECTS = {
    AlertType.FAILOVER_SUCCESS: "[EERF] Failover \uc2e4\ud589 - {fqdn}",
    AlertType.FAILOVER_ROLLBACK: "[EERF] Failover \ub864\ubc31 - {fqdn}",
    AlertType.FAILBACK_SUCCESS: "[EERF] Failback \uc644\ub8cc - {fqdn}",
    AlertType.FAILBACK_FAILED: "[EERF] Failback \uc2e4\ud328 - {fqdn}",
    AlertType.HEALTH_UNHEALTHY: "[EERF] \uc11c\ube44\uc2a4 \uc774\uc0c1 - {fqdn}",
    AlertType.HEALTH_RECOVERED: "[EERF] \uc11c\ube44\uc2a4 \ubcf5\uad6c - {fqdn}",
    AlertType.REPORT_CHANGES: "[EERF] \uc815\uae30 \uc810\uac80 - \ubcc0\uacbd \ubc1c\uc0dd",
    AlertType.REPORT_NO_CHANGES: "[EERF] \uc815\uae30 \uc810\uac80 - \ubcc0\uacbd \uc5c6\uc74c",
    AlertType.ONBOARDING_NEEDED: "[EERF] \uc628\ubcf4\ub529 \ud544\uc694",
    AlertType.GOVERNANCE_APPROVED: "[EERF] \ubcf4\ud638 \uc2b9\uc778 - {fqdn}",
    AlertType.GOVERNANCE_DEFERRED: "[EERF] \ubcf4\ud638 \ubcf4\ub958 - {fqdn}",
    AlertType.GOVERNANCE_EXCLUDED: "[EERF] \ubcf4\ud638 \uc81c\uc678 - {fqdn}",
    AlertType.GOVERNANCE_SUSPENDED: "[EERF] \ubcf4\ud638 \uc911\ub2e8 - {fqdn}",
    AlertType.GOVERNANCE_REOPENED: "[EERF] \uc7ac\uac80\ud1a0 - {fqdn}",
    AlertType.SFN_FAILED: "[EERF] SFN \uc2e4\ud328 - {sfn_name}",
    AlertType.PIPELINE_ERROR: "[EERF] \ud30c\uc774\ud504\ub77c\uc778 \uc624\ub958",
    AlertType.TOKEN_ROTATED: "[EERF] \ud1a0\ud070 \uad50\uccb4 \uc644\ub8cc",
    AlertType.TOKEN_ROTATION_FAILED: "[EERF] \ud1a0\ud070 \uad50\uccb4 \uc2e4\ud328",
    AlertType.HISTORY_WRITE_FAILED: "[EERF] \uc774\ub825 \uae30\ub85d \uc2e4\ud328",
}

def send_alert(alert_type: AlertType, service_key="", fqdn="", account_id="", details="", topic_arn=None, **kwargs) -> bool:
    if topic_arn is None:
        topic_arn = os.environ.get("SNS_TOPIC_ARN", "")
    if not topic_arn:
        return False
    try:
        subject = _SUBJECTS[alert_type].format(fqdn=fqdn or service_key or "unknown", **kwargs)
    except KeyError:
        subject = _SUBJECTS[alert_type].split(" - ")[0]
    if len(subject) > 100:
        subject = subject[:97] + "..."
    body = f"\uc2dc\uac04: {_kst_now()} (KST)\n\uc11c\ube44\uc2a4: {fqdn or service_key}\n\uacc4\uc815: {account_id}\n\n{details}"
    try:
        _get_sns_client().publish(TopicArn=topic_arn, Subject=subject, Message=body)
        return True
    except Exception as e:
        logger.error(f"Alert send failed: {e}")
        return False
