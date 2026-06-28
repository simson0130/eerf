# EERF Product Roadmap

---

## Phase 1 — Recovery Foundation (완료)

자동 복구 핵심 메커니즘.

- Canary CDN+Origin 이중 검증
- 자동 Failover (Route53 + WAF + SG)
- DNS Validate + 자동 Rollback
- Manual Failback
- Cross-Account (STS AssumeRole)

---

## Phase 2 — Production Readiness (현재)

운영자가 신뢰하고 사용할 수 있는 상태.

- Discovery (Organizations 동적 발견)
- HCL Report (온보딩용 Terraform snippet)
- Operator Approval (Pending → Approved)
- Config Repo (terraform.tfvars.shared)
- Terraform Apply → Canary + Failover 자동 생성

---

## Phase 3 — AI Assisted Operations (계획)

운영자 판단을 AI가 보조.

- AI 분석 (서비스 위험도 자동 평가)
- Risk 판단 (변경 영향도 스코어링)
- 운영자 추천 (온보딩 우선순위)
- Explainable Recommendation (왜 이 서비스를 먼저 보호해야 하는지)

---

## Phase 4 — Enterprise Platform (비전)

대규모 조직에서 운영 가능한 플랫폼.

- DynamoDB Service Registry
- API Gateway (운영 API)
- Web Console (관리 UI)
- RBAC (역할 기반 접근 제어)
- 100+ Account 운영 이력 관리

---

## 비용 구조 (Phase 2 기준)

| 리소스 | 월 비용 | 비고 |
|--------|---------|------|
| Lambda (7개) | ~$5 | 1시간 주기 |
| Step Functions | ~$1 | 월 720회 |
| Canary | ~$12/서비스 | 1분 주기 |
| S3 + CloudWatch + SNS | ~$5 | |
| **합계 (서비스 1개)** | **~$23/월** | |
| **서비스 10개** | **~$140/월** | Canary가 주 비용 |

---

## Go-to-Market

1. GitHub 공개 (README + modules + examples)
2. 고객 PoC 1개 (app.company.com)
3. 운영 KPI 대시보드
4. 주간 고객 리뷰 (30분)
5. 동료 피드백 (CA/DevOps/SRE/TAM)
6. Blog + AWS 내부 발표
7. AI 단계 도입
