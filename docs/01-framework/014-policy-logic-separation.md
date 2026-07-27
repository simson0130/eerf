# CORF: 복구정책과 복구로직의 분리

> 최종 업데이트: 2026-07-21

## 핵심 명제

**CORF의 핵심은 복구 코드를 잘 만드는 것보다, 복구정책이 복구로직을 통제하도록 만드는 것이다.**

---

## 왜 분리해야 하는가

| 문제 | 분리 전 | 분리 후 |
|------|---------|--------|
| 정책 변경 | 코드 수정 → 배포 → 테스트 | 설정 변경 → 즉시 반영 |
| 책임 모호 | 누가 "복구하지 말라"고 결정했는지 불명 | 정책 판단 이력에 명확히 기록 |
| 감사 | 코드 diff 추적 필요 | 정책 변경 이력 + 판단 Evidence |
| 확장 | 새 Capability마다 정책 로직 중복 | 공통 정책 계층 재사용 |
| 테스트 | E2E만 가능 | 정책 단위 테스트 + 로직 단위 테스트 |

---

## 구분 정의

```
┌─────────────────────────────────────────────────────────────┐
│  복구정책 (Recovery Policy)                                   │
│  "복구해야 하는가?"                                            │
│                                                              │
│  • 거버넌스 상태 (approved/protected만 허용)                    │
│  • 글로벌 Kill-switch                                         │
│  • Blast radius (동시 FO 제한)                                │
│  • Criticality 기반 판단 (tier1→WAIT, tier3→AUTO)             │
│  • 업무시간 정책 (09-18 KST → 수동 승인 요구)                   │
│  • 상관 장애 감지 (계정 50%+ → 인프라 문제 의심)                  │
│                                                              │
│  결과: ALLOW / DENY / WAIT                                    │
├─────────────────────────────────────────────────────────────┤
│  복구로직 (Recovery Logic)                                     │
│  "어떻게 복구하는가?"                                           │
│                                                              │
│  • Route53 CNAME 전환 (CloudFront → ALB)                      │
│  • WAF 모드 전환 (COUNT → BLOCK)                              │
│  • Emergency SG 연결                                          │
│  • DNS 검증 (resolve + HTTPS 200)                             │
│  • 실패 시 Partial Rollback                                   │
│  • Evidence 기록 (MTTR, before/after)                         │
│                                                              │
│  결과: success / fail / rollback                              │
└─────────────────────────────────────────────────────────────┘
```

---

## EERF 구현 매핑

### 실행 흐름

```
Alarm (CW) → EventBridge → policy_decision.py [정책]
                                  │
                    ┌─────────────┼─────────────┐
                    ↓             ↓             ↓
                 ALLOW          DENY          WAIT
                    │             │             │
                    ↓             ↓             ↓
            SFN 실행 시작      알림 발송     승인 대기 (향후)
                    │
                    ↓
            failover.py [로직]
                    │
            ┌───────┼───────┐
            ↓       ↓       ↓
         Route53   WAF    SG attach
            │
            ↓
      dns_validate.py [검증]
            │
            ↓
      evidence_record.py [증적]
```

### 파일별 역할

| 파일 | 구분 | 역할 |
|------|------|------|
| `policy_decision.py` | **정책** | 판단: ALLOW/DENY/WAIT |
| `failover.py` | **로직** | 실행: DNS+WAF+SG |
| `failback.py` | **로직** | 복원: 역방향 실행 |
| `dns_validate.py` | **로직** | 검증: 서비스 가용성 확인 |
| `evidence_record.py` | **공통** | 증적: 판단+실행 결과 기록 |
| `evaluate.py` | **정책 보조** | 실행 전제조건 평가 (readiness) |

---

## 정책 규칙 구조 (목표 상태)

```json
{
  "PK": "POLICY#global",
  "SK": "RULES",
  "rules": {
    "kill_switch": true,
    "max_concurrent_failover": 3,
    "correlated_failure_threshold": 0.5,
    "criticality_rules": {
      "tier1": {
        "business_hours": "WAIT",
        "off_hours": "ALLOW",
        "correlated": "WAIT"
      },
      "tier2": {
        "business_hours": "ALLOW",
        "off_hours": "ALLOW",
        "correlated": "WAIT"
      },
      "tier3": {
        "default": "ALLOW"
      }
    },
    "maintenance_windows": []
  },
  "version": 3,
  "updated_by": "admin@example.com",
  "updated_at": "2026-07-21T09:00:00Z"
}
```

---

## 구현 현황 (2026-07-21)

| 항목 | 상태 | 비고 |
|------|:----:|------|
| Policy Lambda 물리 분리 | ✅ | policy_decision.py |
| 3종 판단 (ALLOW/DENY/WAIT) | ✅ | |
| Governance gate | ✅ | approved/protected |
| Kill-switch | ✅ | SSM 기반 |
| Blast radius | ✅ | DDB query |
| Criticality 정책 | ✅ | tier1/2/3 |
| 상관 장애 감지 | ✅ | 계정 50% |
| 정책 DDB 저장 | ⬜ | 코드 내 하드코딩 |
| Portal 정책 관리 UI | ⬜ | |
| WAIT→승인 워크플로우 | ⬜ | 알림만 |
| 단일 판단점 (재검사 제거) | ⬜ | failover.py 중복 |
| 정책 시뮬레이션 | ⬜ | |

---

## 설계 결정 근거

### Q: 왜 failover.py에도 safety gate가 남아있는가?

failover.py는 Portal API에서 직접 SFN을 시작하는 경로(리허설, 수동 FO)에서도 호출된다.
이 경우 policy_decision.py를 거치지 않으므로 방어적 재검사가 필요하다.

**해결 방향**: `policy_approved: true` 플래그가 event에 있으면 재검사 skip.
없으면(직접 호출) safety gate 유지.

### Q: 왜 정책을 DDB에 저장해야 하는가?

- 코드 변경 없이 정책 조정 (운영 민첩성)
- Portal에서 비엔지니어가 편집 가능
- 변경 이력 자동 기록 (DDB Stream → eerf-history)
- 서비스별 Override 자연스러운 확장

---

## 관련 문서

- [CORF Principles](principles.md) — P6. Policy-Driven Recovery
- [CORF Lifecycle](lifecycle.md) — Recover stage
- [CORF Compliance](compliance.md) — 점수 기준
- [Architecture](../architecture.md) — Policy Decision Flow

---

## 문서 관계 정리

> 이 문서(014)는 **프레임워크 개념 문서**로서, 정책-로직 분리의 원칙과 현재 구현 상태를 설명합니다.
>
> 구현 시 상세 규칙(MUST/SHOULD/MAY)과 Portal 로드맵은 Kiro steering 파일
> (`.kiro/steering/corf-policy-logic-separation.md`)에 정의되어 있습니다.
>
> **CORF P4 (Evidence Before Success)**와는 별개 원칙입니다.
> P4는 "증적 기록" 의무, 이 문서는 "정책과 로직의 관심사 분리"에 대한 설계 원칙입니다.
