# Approval — Governance State Machine

> 자동 발견 + 인간 승인. 거버넌스를 보장하면서 운영 부담 최소화.

---

## 상태 머신

| 상태 | Canary | 의미 |
|------|:------:|------|
| Pending_Approval | ❌ | 새로 발견됨, 검토 대기 |
| Approved | ✅ | 보호 활성 |
| Deferred | ❌ | 보류 |
| Excluded | ❌ | 영구 제외 |

---

## CLI

```bash
eerf approve <service_key> --reason "..."
eerf defer   <service_key> --reason "..."
eerf exclude <service_key> --reason "..."
eerf reopen  <service_key> --reason "..."
eerf status
eerf list-pending
```

---

## 즉시 알림

모든 상태 변경 → SNS → SES 이메일 즉시 발송 (서비스, 변경 내용, 조작자, 사유)

---

## 감사 로그

```
s3://eerf-audit/audit/approval-transitions/YYYY/MM/DD/{key}-{timestamp}.json
```

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `platform/lambda/approval_state.py` | 상태 머신 로직 |
| `tools/eerf-cli/` | CLI 구현 |
