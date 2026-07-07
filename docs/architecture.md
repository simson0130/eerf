# EERF Architecture Guide

> 이 문서는 EERF를 처음 접하는 엔지니어가 시스템 전체를 이해할 수 있도록 작성되었습니다.

---

## 1. 한 줄 요약

**외부 CDN 장애 시 3분 이내 자동 복구 + 멀티 계정 거버넌스 플랫폼**

---

## 2. 3개 레이어

```
Protection Layer  — "장애 나면 3분 안에 자동으로 살린다"
Governance Layer  — "뭘 보호하고, 뭐가 바뀌었는지 관리한다"
State Layer       — "모든 상태는 DDB, 모든 변경은 자동 이력"
```

---

## 3. Cross-Account 구조

```
Platform Account              Service Account(s)
┌────────────────────┐    ┌──────────────────┐
│ Canary, Alarm, SFN  │    │ Route53, CF, ALB │
│ Lambda (12+3)       │───▶│ WAF, EC2, SG     │
│ DDB, S3, SNS/SES   │    │ Trust Roles x2   │
└────────────────────┘    └──────────────────┘
```

---

## 4. Protection Layer

```
Canary: CDN ✗ + Origin ✓ (연속 2회)
  → Alarm → EventBridge → Step Functions
    ├─ Route53: CNAME CDN → ALB
    ├─ WAF: COUNT → BLOCK
    └─ ALB: Emergency SG
  → Wait 45s → DNS Validate
    ├─ Success → Complete (~3min)
    └─ Fail → Auto-Rollback
```

---

## 5. Governance Layer

```
Discovery → Diff Engine → Report → Enterprise Report → Notification
```

Governance flow: `discovered → pending → approved / deferred / excluded`

---

## 6. DDB 4-Axis Model

| Axis | Writer | Values |
|------|--------|--------|
| CONFIG | discovery.py | ready / not_ready |
| GOVERNANCE | eerf-cli | approved / pending / deferred / excluded |
| OPERATION | failover/failback | standby / failover |
| HEALTH | canary_health_sync | healthy / unhealthy / unknown |

Principles:
- 1 writer per axis (no contention)
- DDB = Single Source of Truth
- DDB Stream → eerf-history (auto audit)
- Optimistic Locking on GOVERNANCE

---

## 7. Lambda Map

```
[1] discovery.py          → CONFIG, ACCOUNT#STATUS
[2] canary_health_sync.py → HEALTH (5min)
[3] failover.py           → OPERATION = failover
    dns_validate.py       → verify (rollback on fail)
[4] failback.py           → OPERATION = standby
[5] eerf-cli              → GOVERNANCE
[6] stream_history.py     → eerf-history (auto)
[7] report_generator.py   → S3 HTML
    report_enterprise.py  → S3 HTML (KPI)
[8] notification.py       → SES email
[9] token_rotation.py     → Canary token (90d)
```

Shared: `dal.py` (DDB), `alert.py` (18 types), `metrics.py` (CW)

---

## 8. Cost

| Item | Per Service | 10 Services |
|------|------------|-------------|
| Canary | $12 | $120 |
| Lambda+SFN+DDB | $7 | $15 |
| S3+SNS+SES | $5 | $5 |
| **Total/mo** | **~$24** | **~$140** |

---

## 9. ADR Summary

| # | Decision | Rationale |
|---|----------|----------|
| 001 | Platform/Service separation | Least privilege |
| 002 | Discovery + Approval | Auto-discover, human-approve |
| 003 | Dead Origin test | Safe CDN failure simulation |
| 004 | Dual-path Canary | Edge-only fault isolation |
| 005 | WAF COUNT→BLOCK | Origin protection without CDN |
| 006 | Manual Failback | Prevent premature rollback |
