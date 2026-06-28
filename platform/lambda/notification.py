"""
EERF Notification Lambda

Sends notifications via SNS and Slack after the governance report is generated.
Supports Normal mode (daily report) and Error mode (pipeline failure).

Mail subject format:
  [EERF] 2026-06-28 20시 점검 보고 - 신규 0 / 변경 0 / 삭제 0

Features:
  - SNS email with full report body (no header duplication)
  - Slack Block Kit notifications
  - Onboarding alert for Pending_Approval services (every run)
  - Deletion alert for disappeared services
  - KST timezone conversion for subject line
  - HCL snippet generation for onboarding

Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
"""
import json
import logging
import os
from typing import Any, Dict, List, Optional
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

import boto3

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")


def _has_changes(diff_summary: Dict[str, int]) -> bool:
    return (
        diff_summary.get("new", 0) > 0
        or diff_summary.get("changed", 0) > 0
        or diff_summary.get("deleted", 0) > 0
    )


def _build_sns_message_normal(diff_summary, report_key, bucket, report_content=""):
    """Body = report content + S3 link. No header duplication with subject."""
    msg = report_content if report_content else ""
    msg += f"\n\n\ubcf4\uace0\uc11c: s3://{bucket}/{report_key}"
    return msg


def _build_sns_message_error(error_step, error_message):
    return "\n".join([
        "[EERF Governance] \u274c Pipeline Error",
        "",
        f"Failed Step: {error_step}",
        f"Message: {error_message}",
        "",
        "Please investigate and resolve the issue.",
    ])


def _send_sns(topic_arn, subject, message, client=None):
    _sns = client or sns_client
    _sns.publish(TopicArn=topic_arn, Subject=subject[:100], Message=message)
    return True


# Full implementation includes:
# - _build_slack_blocks_normal / _build_slack_blocks_error
# - _send_slack (webhook)
# - send_notification (core logic)
# - handler (Lambda entry)
# - Onboarding alert (Pending_Approval every run, KST hour, HCL snippet)
# - Deletion alert (Approved services missing from Discovery)
