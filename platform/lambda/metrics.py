"""
EERF Governance Custom CloudWatch Metrics Helper

Namespace: EERF/Governance
All functions gracefully handle CloudWatch failures (log and continue).
"""
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List

import boto3

logger = logging.getLogger(__name__)
NAMESPACE = "EERF/Governance"
_cw = None

def _get_cw():
    global _cw
    if _cw is None: _cw = boto3.client("cloudwatch")
    return _cw

def _put(data):
    if not data: return True
    try:
        _get_cw().put_metric_data(Namespace=NAMESPACE, MetricData=data)
        return True
    except Exception as e:
        logger.warning(f"Failed to publish metrics: {e}")
        return False

def publish_discovery_metrics(total_discovered, active_protected, error_count, canary_coverage, review_required=0):
    ts = datetime.now(timezone.utc)
    return _put([
        {"MetricName": "TotalDiscovered", "Timestamp": ts, "Value": float(total_discovered), "Unit": "Count"},
        {"MetricName": "ActiveProtected", "Timestamp": ts, "Value": float(active_protected), "Unit": "Count"},
        {"MetricName": "ErrorCount", "Timestamp": ts, "Value": float(error_count), "Unit": "Count"},
        {"MetricName": "CanaryCoverage", "Timestamp": ts, "Value": float(canary_coverage), "Unit": "Percent"},
        {"MetricName": "ReviewRequired", "Timestamp": ts, "Value": float(review_required), "Unit": "Count"},
    ])

def publish_diff_metrics(excluded, drift_detected, deleted=0, failover=0):
    ts = datetime.now(timezone.utc)
    return _put([
        {"MetricName": "Excluded", "Timestamp": ts, "Value": float(excluded), "Unit": "Count"},
        {"MetricName": "DriftDetected", "Timestamp": ts, "Value": 1.0 if drift_detected else 0.0, "Unit": "Count"},
        {"MetricName": "DeletedCount", "Timestamp": ts, "Value": float(deleted), "Unit": "Count"},
        {"MetricName": "FailoverActive", "Timestamp": ts, "Value": float(failover), "Unit": "Count"},
    ])

def publish_report_metrics(pending_approval, approved=0):
    ts = datetime.now(timezone.utc)
    return _put([
        {"MetricName": "PendingApproval", "Timestamp": ts, "Value": float(pending_approval), "Unit": "Count"},
        {"MetricName": "ActiveProtected", "Timestamp": ts, "Value": float(approved), "Unit": "Count"},
    ])
