"""
EERF Onboarding PR Generator Lambda

Creates a GitHub Pull Request to add a new service JSON file when a service
is approved via the CLI or S3 event trigger.

Behavior:
  1. event payload에서 service_key, account_id, fqdn, service_config 추출
  2. SSM SecureString에서 GitHub Personal Access Token 조회
  3. GitHub API로 default branch의 latest commit SHA 조회
  4. Branch `eerf/onboard-{service_key}` 생성 (이미 존재하면 skip — 멱등성)
  5. `services/{service_key}.json` 파일을 해당 branch에 생성
  6. PR 생성: 제목 `[EERF] Onboard: {fqdn} ({account_id})`
  7. 성공 시 SNS 알림 발송
  8. AUTO_MERGE=true인 경우 PR에 auto-merge 활성화 (squash)

Environment Variables:
  GITHUB_TOKEN_SSM_NAME: SSM SecureString 파라미터 이름 (GitHub PAT)
  GITHUB_REPO: owner/repo 형식
  AUDIT_BUCKET: 감사 로그 S3 버킷
  SNS_TOPIC_ARN: 알림용 SNS 토픽 ARN
  NAME_PREFIX: EERF 이름 prefix (기본: eerf)
  AUTO_MERGE: "true"이면 PR에 auto-merge 활성화
"""
import json
import logging
import os
import urllib.request
import urllib.error
from datetime import datetime, timezone

import boto3

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

ssm = boto3.client("ssm")
sns = boto3.client("sns")
s3 = boto3.client("s3")

GITHUB_TOKEN_SSM_NAME = os.environ.get("GITHUB_TOKEN_SSM_NAME", "")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "")
AUDIT_BUCKET = os.environ.get("AUDIT_BUCKET", "")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
NAME_PREFIX = os.environ.get("NAME_PREFIX", "eerf")
AUTO_MERGE = os.environ.get("AUTO_MERGE", "false").lower() == "true"

GITHUB_API_BASE = "https://api.github.com"


class BranchAlreadyExistsError(Exception):
    pass


class PRCreationError(Exception):
    pass


def _get_github_token() -> str:
    try:
        resp = ssm.get_parameter(Name=GITHUB_TOKEN_SSM_NAME, WithDecryption=True)
        return resp["Parameter"]["Value"]
    except Exception as e:
        raise RuntimeError(f"Failed to retrieve GitHub token from SSM: {e}")


def _github_request(method: str, path: str, token: str, data: dict = None) -> dict:
    url = f"{GITHUB_API_BASE}{path}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json",
        "User-Agent": "EERF-Onboarding-Lambda",
    }
    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp_body = resp.read().decode("utf-8")
            return json.loads(resp_body) if resp_body else {}
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else ""
        logger.error(f"GitHub API error: {e.code} {e.reason} - {error_body}")
        raise


def _get_default_branch_sha(token: str) -> tuple:
    repo_info = _github_request("GET", f"/repos/{GITHUB_REPO}", token)
    default_branch = repo_info["default_branch"]
    ref_info = _github_request("GET", f"/repos/{GITHUB_REPO}/git/ref/heads/{default_branch}", token)
    sha = ref_info["object"]["sha"]
    return default_branch, sha


def _branch_exists(token: str, branch_name: str) -> bool:
    try:
        _github_request("GET", f"/repos/{GITHUB_REPO}/git/ref/heads/{branch_name}", token)
        return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


def _create_branch(token: str, branch_name: str, sha: str) -> dict:
    return _github_request("POST", f"/repos/{GITHUB_REPO}/git/refs", token, data={"ref": f"refs/heads/{branch_name}", "sha": sha})


def _create_file_on_branch(token: str, branch_name: str, file_path: str, content: str, message: str) -> dict:
    import base64
    encoded_content = base64.b64encode(content.encode("utf-8")).decode("utf-8")
    return _github_request("PUT", f"/repos/{GITHUB_REPO}/contents/{file_path}", token, data={"message": message, "content": encoded_content, "branch": branch_name})


def _create_pull_request(token: str, title: str, head: str, base: str, body: str) -> dict:
    return _github_request("POST", f"/repos/{GITHUB_REPO}/pulls", token, data={"title": title, "head": head, "base": base, "body": body})


def handler(event, context):
    """Lambda handler for Onboarding PR creation."""
    service_key = event.get("service_key")
    account_id = event.get("account_id", "")
    fqdn = event.get("fqdn", "")

    if not service_key:
        raise ValueError("event must contain 'service_key' field")

    branch_name = f"eerf/onboard-{service_key}"

    try:
        token = _get_github_token()
        default_branch, base_sha = _get_default_branch_sha(token)

        if _branch_exists(token, branch_name):
            return {"action": "onboarding_pr", "status": "skipped", "reason": f"Branch '{branch_name}' already exists"}

        _create_branch(token, branch_name, base_sha)

        file_path = f"platform/services/{service_key}.json"
        service_config = event.get("service_config", {})
        file_content = json.dumps(service_config, indent=2, ensure_ascii=False) if service_config else '{}'
        _create_file_on_branch(token, branch_name, file_path, file_content, f"[EERF] Add service config: {service_key}")

        pr_title = f"[EERF] Onboard: {fqdn} ({account_id})"
        pr_body = f"## EERF Service Onboarding\n\nService Key: `{service_key}`\nFQDN: `{fqdn}`\nAccount: `{account_id}`"
        pr_resp = _create_pull_request(token, pr_title, branch_name, default_branch, pr_body)

        pr_url = pr_resp.get("html_url", "")
        if SNS_TOPIC_ARN:
            sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=f"[EERF] Onboarding PR created - {service_key}", Message=f"PR URL: {pr_url}")

        return {"action": "onboarding_pr", "status": "created", "pr_url": pr_url}

    except Exception as e:
        logger.error(f"Failed to create onboarding PR: {e}")
        if SNS_TOPIC_ARN:
            sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=f"[EERF] PR creation failed - {service_key}", Message=str(e))
        raise
