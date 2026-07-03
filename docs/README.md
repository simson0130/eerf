# EERF - Enterprise Edge Recovery Framework

**외부 CDN 장애 시 AWS Origin으로 3분 이내 자동 전환하는 엔터프라이즈 복구 플랫폼**

---

## 이 프로젝트가 해결하는 문제

| 기존 | EERF 적용 후 |
|------|-------------|
| CDN 장애 시 수동 DNS 변경 (30분~수시간) | 자동 감지 후 3분 이내 전환 |
| Edge 장애인지 Origin 장애인지 구분 불가 | CDN + Origin 교차 검증으로 정확한 판단 |
| CDN 보호가 벗겨지면 Origin 노출 | WAF 자동 BLOCK + Emergency SG |
| 전환했는데 더 장애가 커지면? | 검증 실패 시 자동 롤백 |
| 새 서비스 보호에 며칠 | Discovery 자동 발견 후 수분 내 온보딩 |
| 누가 언제 뭘 바꿨는지 모름 | 모든 변경 자동 이력 추적 |

---

## 핵심 동작

```
User -> CDN -> [장애 발생]
                    |
         Canary 감지 (1분 주기, 연속 2회)
                    |
         Failover 자동 실행
           - Route53: CDN -> ALB
           - WAF: COUNT -> BLOCK
           - SG: Emergency 연결
                    |
         DNS + HTTP 검증 (성공 시 완료, 실패 시 자동 롤백)
                    |
User -> ALB (직접) -> App [서비스 정상]
```

전체 소요: 약 3분. 무인 24/7.

---

## 아키텍처

```
Platform Account (오케스트레이션)
  Canary / Alarm / Step Functions / Lambda
  DynamoDB (4축 상태 모델 + History)
  SNS / SES / Dashboard
            |
            | sts:AssumeRole
            v
Service Account(s) (기존 운영 인프라)
  Route53 / CloudFront / ALB / WAF / EC2
  + Trust Role 2개만 추가 (무중단)
```

---

## 현재 상태

- Stage 4 (Trust) 달성
- 3개 서비스 보호 운영 중
- E2E Failover/Failback 검증 완료
- DynamoDB 4축 상태 모델 + Stream History
- 통합 알림 (18종) + 감사 증적 체계
- CLI (`eerf status`, `eerf approve`, `eerf history`)

---

## 빠르게 시작하기

```powershell
# 상태 확인
eerf --bucket <audit-bucket> status

# 서비스 승인
eerf --bucket <audit-bucket> approve "계정ID:fqdn" --reason "보호 대상"

# 변경 이력 조회
eerf --bucket <audit-bucket> history app-srv1-6693

# 배포
cd platform
terraform apply -var-file="terraform.tfvars.shared"
```

---

## 문서 구조

### 설계 원칙

| 문서 | 설명 |
|------|------|
| [platform/principles.md](platform/principles.md) | Recovery Automation 7원칙 + 5-Stage 성숙도 모델 |

### 제품

| 문서 | 설명 |
|------|------|
| [product/overview.md](product/overview.md) | EERF 전체 소개, 6가지 핵심 기능, 데이터 모델 |
| [product/executive-summary.md](product/executive-summary.md) | 비즈니스 가치 요약 (의사결정자 대상) |
| [product/roadmap.md](product/roadmap.md) | Phase 1~7 로드맵 |

### 기술 설계

| 문서 | 설명 |
|------|------|
| [architecture/system-design.md](architecture/system-design.md) | 전체 아키텍처 + 기능별 Flow 7개 |
| [architecture/data-model.md](architecture/data-model.md) | DynamoDB Single Table + History Table |
| [architecture/adr/](architecture/adr/) | Architecture Decision Records |

### 운영 가이드

| 문서 | 설명 |
|------|------|
| [guides/installation.md](guides/installation.md) | 설치, 배포, 프로젝트 구조 |
| [guides/operations.md](guides/operations.md) | 일일 운영, CLI, 알림 체계, 트러블슈팅 |
| [guides/onboarding.md](guides/onboarding.md) | 신규 서비스 보호 등록 |
| [guides/failover.md](guides/failover.md) | Failover 절차 상세 |
| [guides/failback.md](guides/failback.md) | Failback 절차 상세 |

### 테스트 / 변경이력

| 문서 | 설명 |
|------|------|
| [testing/test-runbook.md](testing/test-runbook.md) | E2E 테스트 시나리오 + 체크리스트 |
| [changelog/progress.md](changelog/progress.md) | 전체 진행 추적 (#1~#82) |

---

## 설계 원칙 (요약)

1. **Dual-Path Detection** - 장애를 2개 경로로 교차 검증 (오탐 방지)
2. **Verify-then-Trust** - 복구 후 반드시 검증, 실패 시 자동 롤백
3. **Transaction Rollback** - 부분 실패 시 완료된 단계 역순 원복
4. **Governance First** - 자동화 범위를 사람이 통제
5. **Single Source of Truth** - 상태는 한 곳에서만 관리 (DynamoDB)
6. **Audit Everything** - 모든 변경과 운영자 행위를 추적
7. **Manual Failback** - 자동 복구는 하되, 원복 판단은 사람에게

상세: [platform/principles.md](platform/principles.md)

---

## 비용

| 서비스 수 | 월 비용 | 비고 |
|----------|---------|------|
| 1개 | ~$24 | Canary가 주 비용 |
| 10개 | ~$145 | Lambda/DDB는 미미 |
| 50개 | ~$650 | 선형 증가 (Canary x N) |

---

## 기술 스택

- Terraform (IaC)
- Python 3.13 (Lambda)
- DynamoDB (상태 + 이력)
- Step Functions (오케스트레이션)
- CloudWatch Synthetics (Canary)
- EventBridge + SNS + SES (이벤트 + 알림)
- Click (CLI)
