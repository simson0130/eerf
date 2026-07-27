"""
EERF CloudWatch Metrics Module
"""
import os
from datetime import datetime, timezone
import boto3

NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")
_cw = None

def _get_cw():
    global _cw
    if _cw is None: _cw = boto3.client("cloudwatch")
    return _cw

def _put_metrics(metric_data: list):
    """CloudWatch PutMetricData wrapper."""
    _get_cw().put_metric_data(Namespace=f"{NAME_PREFIX}/Platform", MetricData=metric_data)

def put_service_metric(service_key: str, metric_name: str, value: float, unit: str = "Count"):
    _put_metrics([{
        "MetricName": metric_name,
        "Timestamp": datetime.now(timezone.utc),
        "Value": value,
        "Unit": unit,
        "Dimensions": [{"Name": "ServiceKey", "Value": service_key}],
    }])
