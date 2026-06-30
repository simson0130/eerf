"""
EERF Governance Custom CloudWatch Metrics Helper

Publishes custom metrics to CloudWatch under the EERF/Governance namespace.
All functions gracefully handle CloudWatch failures (log and continue).

Namespace: EERF/Governance
Metrics:
  - TotalDiscovered
  - ActiveProtected
  - ErrorCount
  - CanaryCoverage
  - Excluded
  - DriftDetected
  - PendingApproval
"""
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import boto3

logger = logging.getLogger(__name__)

NAMESPACE = "EERF/Governance"

_cloudwatch_client = None


def _get_cloudwatch_client():
    global _cloudwatch_client
    if _cloudwatch_client is None:
        _cloudwatch_client = boto3.client("cloudwatch")
    return _cloudwatch_client


def _put_metrics(metric_data: List[Dict[str, Any]]) -> bool:
    if not metric_data:
        return True
    try:
        client = _get_cloudwatch_client()
        client.put_metric_data(Namespace=NAMESPACE, MetricData=metric_data)
        return True
    except Exception as e:
        logger.warning(f"[EERF] Failed to publish CloudWatch metrics: {e}")
        return False


def publish_discovery_metrics(
    total_discovered: int,
    active_protected: int,
    error_count: int,
    canary_coverage: float,
    review_required: int = 0,
) -> bool:
    timestamp = datetime.now(timezone.utc)
    metric_data = [
        {"MetricName": "TotalDiscovered", "Timestamp": timestamp, "Value": float(total_discovered), "Unit": "Count"},
        {"MetricName": "ActiveProtected", "Timestamp": timestamp, "Value": float(active_protected), "Unit": "Count"},
        {"MetricName": "ErrorCount", "Timestamp": timestamp, "Value": float(error_count), "Unit": "Count"},
        {"MetricName": "CanaryCoverage", "Timestamp": timestamp, "Value": float(canary_coverage), "Unit": "Percent"},
        {"MetricName": "ReviewRequired", "Timestamp": timestamp, "Value": float(review_required), "Unit": "Count"},
    ]
    return _put_metrics(metric_data)


def publish_diff_metrics(excluded: int, drift_detected: bool, deleted: int = 0, failover: int = 0) -> bool:
    timestamp = datetime.now(timezone.utc)
    metric_data = [
        {"MetricName": "Excluded", "Timestamp": timestamp, "Value": float(excluded), "Unit": "Count"},
        {"MetricName": "DriftDetected", "Timestamp": timestamp, "Value": 1.0 if drift_detected else 0.0, "Unit": "Count"},
        {"MetricName": "DeletedCount", "Timestamp": timestamp, "Value": float(deleted), "Unit": "Count"},
        {"MetricName": "FailoverActive", "Timestamp": timestamp, "Value": float(failover), "Unit": "Count"},
    ]
    return _put_metrics(metric_data)


def publish_report_metrics(pending_approval: int, approved: int = 0) -> bool:
    timestamp = datetime.now(timezone.utc)
    metric_data = [
        {"MetricName": "PendingApproval", "Timestamp": timestamp, "Value": float(pending_approval), "Unit": "Count"},
        {"MetricName": "ActiveProtected", "Timestamp": timestamp, "Value": float(approved), "Unit": "Count"},
    ]
    return _put_metrics(metric_data)
