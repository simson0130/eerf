"""
EERF Governance Custom CloudWatch Metrics Helper

Namespace: EERF/Governance
Metrics: TotalDiscovered, ActiveProtected, ErrorCount, CanaryCoverage,
         Excluded, DriftDetected, PendingApproval, FailoverActive, ReviewRequired
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


def _put_metrics(metric_data):
    try:
        _get_cloudwatch_client().put_metric_data(Namespace=NAMESPACE, MetricData=metric_data)
        return True
    except Exception as e:
        logger.warning(f"Failed to publish CloudWatch metrics: {e}")
        return False


def publish_discovery_metrics(total_discovered=0, active_protected=0, error_count=0, canary_coverage=0.0, review_required=0):
    ts = datetime.now(timezone.utc)
    return _put_metrics([
        {"MetricName": "TotalDiscovered", "Timestamp": ts, "Value": float(total_discovered), "Unit": "Count"},
        {"MetricName": "ActiveProtected", "Timestamp": ts, "Value": float(active_protected), "Unit": "Count"},
        {"MetricName": "ErrorCount", "Timestamp": ts, "Value": float(error_count), "Unit": "Count"},
        {"MetricName": "CanaryCoverage", "Timestamp": ts, "Value": float(canary_coverage), "Unit": "Percent"},
        {"MetricName": "ReviewRequired", "Timestamp": ts, "Value": float(review_required), "Unit": "Count"},
    ])


def publish_diff_metrics(excluded=0, drift_detected=False, deleted=0, failover=0):
    ts = datetime.now(timezone.utc)
    return _put_metrics([
        {"MetricName": "Excluded", "Timestamp": ts, "Value": float(excluded), "Unit": "Count"},
        {"MetricName": "DriftDetected", "Timestamp": ts, "Value": 1.0 if drift_detected else 0.0, "Unit": "Count"},
        {"MetricName": "Deleted", "Timestamp": ts, "Value": float(deleted), "Unit": "Count"},
        {"MetricName": "FailoverActive", "Timestamp": ts, "Value": float(failover), "Unit": "Count"},
    ])


def publish_report_metrics(pending_approval=0, approved=0):
    ts = datetime.now(timezone.utc)
    return _put_metrics([
        {"MetricName": "PendingApproval", "Timestamp": ts, "Value": float(pending_approval), "Unit": "Count"},
        {"MetricName": "ActiveProtected", "Timestamp": ts, "Value": float(approved), "Unit": "Count"},
    ])
