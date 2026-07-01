# Failover / Failback — Recovery Orchestration

> 감지 → 판단 → 전환 → 검증을 하나의 워크플로우로 자동화.

---

## Failover 흐름

```
Alarm(ALARM) → EventBridge → Step Functions
  └── ExecuteFailover (AssumeRole → Route53 + WAF + SG)
  └── Wait 45s
  └── ValidateDNS
        ├── 성공 → Success
        └── 실패(8회) → RollbackFailback → Fail
```

---

## Failover Lambda 동작

| # | 동작 | 목적 |
|---|------|------|
| 1 | SSM에서 서비스 설정 로드 | service_key → 동적 조회 |
| 2 | Idempotency 체크 | 이미 FO면 skip |
| 3 | Route53 CNAME → ALB | DNS 전환 |
| 4 | WAF COUNT → BLOCK | Origin 보호 |
| 5 | Emergency SG 연결 | 직접 접근 허용 |
| 6 | 감사 로그 + 알림 | 추적 |

---

## Failback (수동)

이유: FO 후 Canary는 ALB로 체크 → 항상 성공 → CDN 복구 오판 가능.

```bash
aws stepfunctions start-execution \
  --state-machine-arn ...eerf-{key}-manual-failback \
  --input '{}'
```

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `platform/lambda/failover.py` | Failover Lambda |
| `platform/lambda/failback.py` | Failback Lambda |
| `platform/failover.tf` | Step Functions 정의 |

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| AssumeRole 실패 | Trust policy 미설정 | eerf-platform-trust 확인 |
| WAF update 실패 | LockToken 충돌 | 3회 재시도 동작 확인 |
| SFN TIMED_OUT | Validate 8회 실패 | ALB Target health 확인 |
