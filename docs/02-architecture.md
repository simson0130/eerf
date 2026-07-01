# EERF Architecture — Technical Deep Dive

---

## 1. Core Capabilities

EERF는 5가지 핵심 기능이 유기적으로 연결되어 "안전한 자동 복구 플랫폼"을 구성합니다.

### 1.1 Dual-Path Canary — Edge만 죽었는지 정확히 판단

| 문제 | 해결 |
|------|------|
| CDN 장애 vs Origin 장애 구분 불가 | CDN + Origin 두 경로 동시 체크 |
| Origin도 죽었는데 Failover → 무의미 | `CDN ✗ AND Origin ✓` 일 때만 FO |

```
CDN ✗ + Origin ✓ → ALARM  (Edge-only fault → Failover 실행)
CDN ✗ + Origin ✗ → ALARM  (전체 장애 → 알림만, FO 안 함)
CDN ✓            → OK     (정상)
```

- `x-canary-token` 헤더로 WAF BLOCK 상태에서도 검증 통과
- Canary는 Platform Account에서 실행 (Service VPC 무관)
- 1분 주기, 연속 2회 실패 시 ALARM

### 1.2 Decision Engine (Step Functions) — 감지부터 복구까지 표준화

```
Alarm → ExecuteFailover → Wait(45s) → ValidateDNS
                                          ├── 성공 → Complete
                                          └── 실패 → Auto-Rollback → Fail
```

모든 실행마다:
- S3 감사 로그 기록
- SNS/SES 즉시 알림 발송
- SSM 상태 플래그 업데이트 (normal/failover)

### 1.3 Post-Switch Validation + Auto-Rollback — 전환해도 안전하다는 보장

**이것이 EERF와 단순 DNS Failover의 핵심 차이점입니다.**

| 검증 항목 | 목적 |
|-----------|------|
| DNS Resolve (FQDN → IP) | Route53 전파 완료 확인 |
| Route53 API Fallback | Lambda DNS 캐시 우회 |
| HTTPS 200 응답 | ALB + App 실제 정상 확인 |
| x-canary-token 헤더 | WAF BLOCK 상태에서도 검증 가능 |

```
재시도: 8회 × 15초 = 최대 2분
  → 성공: Failover 완료 (전체 < 3분)
  → 실패: 자동 Failback 실행 (원래 상태 복원)
```

**이게 없으면:** Failover가 장애를 더 키우는 상황 발생 가능.
**이게 있으면:** "전환은 했는데 안 되면 어쩌지?"에 대한 답.

### 1.4 WAF Auto-Hardening — CDN 없이도 Origin 보호

```
정상: User → CDN(방어) → ALB → WAF(COUNT) → App
FO:   User → ALB(직접) → WAF(BLOCK) → App
                          ↑ Failover Lambda가 자동 전환
```

- Managed Rules: COUNT → BLOCK (override_action: None)
- AllowCanaryHealthCheck: 항상 ALLOW 유지
- RateBasedRule: COUNT 유지 (오탐 최소화)
- Failback 시 자동 복원: BLOCK → COUNT

### 1.5 Governance Pipeline — 보호 사각지대 자동 발견

```
EventBridge(hourly) → Discovery → Diff Engine → Report Generator → Notification
                         ↓              ↓              ↓               ↓
                    Org 전체 스캔   변경 분류      HTML 보고서    SES/Slack 전달
```

- 매 시간 Organizations 전체 계정 스캔
- 신규/변경/삭제 서비스 자동 분류
- 보호 커버리지 % 계산 + 대시보드 반영
- 운영자는 `eerf approve` / `eerf defer`로 결정만

---

## 2. 계정 구조

### Platform Account (오케스트레이션 전용)

| 구성요소 | 역할 |
|----------|------|
| Synthetics Canary | CDN + Origin 이중 모니터링 (서비스별) |
| CloudWatch Alarm | 연속 2회 실패 → ALARM |
| EventBridge | Alarm→SFN 트리거 + 정시 스캔 스케줄 |
| Step Functions | Failover/Failback/Governance 오케스트레이션 |
| Lambda (Recovery) | Failover / Failback / DNS Validate |
| Lambda (Governance) | Discovery / Diff / Report / Notification |
| Lambda (보조) | Token Rotation / Onboarding PR |
| SSM Parameter Store | 서비스 설정, 상태 플래그, Canary 토큰 |
| S3 Audit Bucket | 스냅샷, 보고서, approval-state, 감사 로그 |
| SNS + SES | 즉시 알림 |
| CloudWatch Dashboard | 통합 운영 가시성 |

### Service Account(s) (이미 운영 중)

| 구성요소 | EERF 도입 시 변경 |
|----------|------------------|
| Route53 / CloudFront / ALB / WAF / EC2 | **변경 없음** |
| `eerf-discovery-trust` Role | 신규 추가 (읽기 전용) |
| `eerf-platform-trust` Role | 신규 추가 (FO/FB 실행용) |

---

## 3. Cross-Account IAM

### Discovery (읽기)
```
Platform (eerf-discovery-role) ──AssumeRole──▶ Service (eerf-discovery-trust)
```
권한: Route53 List, ELB Describe, ACM List, WAF Get, EC2 DescribeSG, CloudFront List

### Recovery (쓰기)
```
Platform (eerf-lambda-role) ──AssumeRole──▶ Service (eerf-platform-trust)
```
권한: Route53 Change, WAF Update, ELB SetSecurityGroups

---

## 4. SSM Parameter Store 구조

| 경로 | 용도 | 접근 주체 |
|------|------|-----------|
| `/eerf/services/{service_key}` | 서비스 설정 JSON | Failover/Failback Lambda |
| `/eerf/discovery/{account_id}/{subdomain}` | Discovery 매니페스트 | Discovery Lambda |
| `/eerf/canary/token` | Canary 인증 토큰 (SecureString) | Canary, Token Rotation |
| `/eerf/status/{service_key}` | 상태 플래그 (normal/failover) | Failover/Failback Lambda |
| `/eerf/config/sns-topic-arn` | SNS Topic ARN | CLI |

서비스 50개여도 Lambda는 고정 — `service_key`로 SSM 동적 조회.

---

## 5. Recovery Flow 상세

### Failover (자동)

| # | 동작 | 위치 |
|---|------|------|
| 1 | Canary ALARM → EventBridge → Step Functions | Platform |
| 2 | Idempotency 체크 (이미 FO면 skip) | Service |
| 3 | Route53 CNAME: CloudFront → ALB | Service |
| 4 | WAF: COUNT → BLOCK | Service |
| 5 | ALB: Emergency SG 연결 | Service |
| 6 | 감사 로그 + SNS 알림 | Platform |
| 7 | Wait 45초 (DNS 전파) | Platform |
| 8 | **DNS Validate: resolve + health check** | Platform→Service |
| 9 | 성공 → Complete / **실패 → 자동 Rollback** | Platform |

### Failback (수동)

| # | 동작 |
|---|------|
| 1 | 운영자가 CDN 복구 확인 (수동 판단) |
| 2 | Manual Failback SFN 실행 |
| 3 | Route53 CNAME: ALB → CloudFront |
| 4 | WAF: BLOCK → COUNT |
| 5 | Emergency SG 제거 |
| 6 | Wait 45초 → DNS Validate |

---

## 6. Governance Lifecycle

```
Discovery ─────▶ Approval ─────▶ Onboarding ─────▶ Monitoring
   │                │                │                 │
   ▼                ▼                ▼                 ▼
Org 스캔         4-State 머신     JSON 파일 1개     Canary 활성
자동 발견        approve/defer    terraform apply   1분 체크
```

### Approval 상태 머신

| 상태 | 의미 | Canary |
|------|------|--------|
| Pending_Approval | 새로 발견됨, 검토 대기 | ❌ |
| Approved | 보호 활성 | ✅ |
| Deferred | 보류 (추후 재검토) | ❌ |
| Excluded | 영구 제외 | ❌ |

### Onboarding = JSON 파일 1개

```
platform/services/
├── app-srv1-6693.json     ← terraform apply → Canary + Alarm + SFN 생성
├── app-portal-7151.json
└── api-backend-9643.json
```

---

## 7. 알림 체계

| 이벤트 | 내용 | 채널 |
|--------|------|------|
| Canary ALARM | CDN 경로 장애 감지 | SNS |
| Failover 실행 | 전환 상세 (서비스, FQDN, 시간) | SNS + SES |
| Failback 실행 | 복원 상세 | SNS + SES |
| SFN 실패 | Step Functions 실행 오류 | SNS (즉시) |
| 상태 변경 | approve/defer/exclude | SES (즉시) |
| 정기 보고 | 매 시간 거버넌스 리포트 | SES (HTML) |
| 신규 발견 | 미보호 서비스 감지 | SNS + SES |

---

## 8. Design Decisions (요약)

| ADR | 결정 | 핵심 이유 |
|-----|------|-----------|
| [001](adr/ADR-001-platform-service-separation.md) | Platform/Service 분리 | 최소 권한 + 멀티 계정 확장 |
| [002](adr/ADR-002-discovery-approval-model.md) | Discovery + Approval | 자동 발견 + 인간 승인 |
| [003](adr/ADR-003-dead-origin-simulation.md) | Dead Origin 테스트 | 안전한 CDN 장애 시뮬레이션 |
| [004](adr/ADR-004-canary-dual-path-check.md) | Dual-path Canary | Edge-only 장애 식별 |
| [005](adr/ADR-005-waf-count-to-block.md) | WAF 자동 전환 | CDN 없이 Origin 보호 |
| [006](adr/ADR-006-manual-failback.md) | 수동 Failback | 조기 롤백 방지 |

---

## 9. 컴포넌트별 상세 문서

| 문서 | 내용 |
|------|------|
| [components/canary.md](components/canary.md) | Canary 설계, 토큰 로테이션, 오탐 방지 |
| [components/failover.md](components/failover.md) | Failover Lambda, Idempotency, WAF LockToken |
| [components/dns-validate.md](components/dns-validate.md) | DNS 검증, 재시도, Route53 API Fallback |
| [components/governance.md](components/governance.md) | Discovery, Diff, Report, Notification 파이프라인 |
| [components/approval.md](components/approval.md) | 상태 머신, CLI, 전환 규칙, 감사 로그 |
| [components/security.md](components/security.md) | IAM, WAF, SG, 네트워크 설계 |
