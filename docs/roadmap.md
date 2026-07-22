# EERF Product Roadmap

> 최종 업데이트: 2026-07-21
> 이 문서는 EERF를 처음부터 구축할 때의 구현 순서 가이드이자, 현재 진행 상황을 보여줍니다.

---

## 현재 위치

```
Phase 1 ✅ → Phase 2 ✅ → Phase 3 ✅ → Phase 4 ✅ (Production Ready)
                                                    Phase 5 ⬜ (설계 완료)
                                                    Phase 6 ⬜ (구상)
                                                    Phase 7 ⬜ (비전)
```

**CORF Compliance: Compliant ✅ (MUST 37/37 PASS, Maturity 51/100)**

---

## Phase 설계 원칙

1. **각 Phase 완료 시 독립적으로 배포·운영 가능** (가치 제공)
2. **다음 Phase는 이전 Phase가 전제** (건너뛰기 불가)
3. **Phase 이름만으로 "이 단계에서 미를 할 수 있는지" 명확**
4. **한 Phase = 1~3주 작업** (적정 크기)

---

## Phase 1: 단일 서비스 복구 ✅

> **"1개 서비스가 CDN 장애 시 3분 내 자동 복구된다"**

| 구현 항목 | CORF 단계 | 상태 |
|-----------|:---------:|:----:|
| Canary (CDN+Origin 이중 경로) | Detect | ✅ |
| CloudWatch Alarm (연속 2회 실패 → ALARM) | Detect | ✅ |
| Failover Lambda (Route53+WAF+SG) | Recover | ✅ |
| DNS Validate + 자동 Rollback | Recover | ✅ |
| Manual Failback SFN (별도 워크플로우) | Restore | ✅ |
| Cross-Account IAM | — | ✅ |
| S3 감사 로그 | Operate | ✅ |

---

## Phase 2: 멀티 서비스 거버넌스 ✅

> **"Organizations 전체를 스캔하여 보호 대상을 자동 발견하고, 상태 머신으로 관리한다"**

| 구현 항목 | CORF 단계 | 상태 |
|-----------|:---------:|:----:|
| Discovery Lambda (Organizations 멀티 계정 스캔) | Discover | ✅ |
| DynamoDB 4축 상태 모델 | State | ✅ |
| Evaluate Lambda (8항목 Readiness) | Evaluate | ✅ |
| Governance State Machine (7단계 전이) | Approve | ✅ |
| DDB Stream → History | Operate | ✅ |
| 보고서 2종 + SES 알림 19종 | Operate | ✅ |
| for_each 기반 멀티 서비스 | Protect | ✅ |
| auto-suspend / auto-promote | Evaluate | ✅ |

---

## Phase 3: 운영 포탈 ✅

> **"CLI 없이 브라우저에서 전체 현황 관리, 거버넌스 조작, FO 테스트 가능"**

| 구현 항목 | CORF 단계 | 상태 |
|-----------|:---------:|:----:|
| React SPA (20페이지) + API 27+ | Operate | ✅ |
| Cognito 인증 + RBAC | Approve | ✅ |
| 대시보드 (KPI + MTTD/MTTR) | Operate | ✅ |
| FO 테스트 + Failback UI | Recover+Restore | ✅ |
| S3 + CloudFront 호스팅 | — | ✅ |

---

## Phase 4: 프로덕션 강화 ✅

> **"안전장치·정책·증적 불변성으로 프로덕션 수준 신뢰도 확보. CORF Compliant 달성."**

| 구현 항목 | CORF 단계 | 상태 |
|-----------|:---------:|:----:|
| Policy Decision Lambda (DDB 기반) | Recover | ✅ |
| Kill-switch + Blast radius | Recover | ✅ |
| Evidence immutability (S3 Object Lock) | Operate | ✅ |
| Policy-Logic Separation | Recover | ✅ |
| Portal 정책 관리 UI | Operate | ✅ |
| CORF MUST 37/37 PASS | 전체 | ✅ |

---

## Phase 5: 자동화 파이프라인 ⬜ (설계 완료)

> **"approve → auto PR → merge → terraform apply → protected"**

---

## Phase 6: 멀티 CDN 확장 ⬜ (구상)

> **"Cloudflare/Akamai 등 외부 CDN에 동일 CORF 라이프사이클 적용"**

---

## Phase 7: 지능형 운영 ⬜ (비전)

> **"AI가 장애를 예측하고, 정책을 추천하고, 자연어로 운영"**

---

## CORF Compliance

**현재: Compliant ✅ (MUST 37/37 PASS)**

| CORF 단계 | MUST | Verdict | Maturity |
|-----------|:----:|:-------:|:--------:|
| Discover | 4/4 | PASS | 40 |
| Evaluate | 5/5 | PASS | 40 |
| Approve | 6/6 | PASS | 0 |
| Protect | 3/3 | PASS | 53 |
| Recover | 10/10 | PASS | 64 |
| Restore | 5/5 | PASS | 80 |
| Operate | 4/4 | PASS | 80 |
