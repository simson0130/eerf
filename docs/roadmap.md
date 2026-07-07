# EERF Product Roadmap

---

## Phase 1 — Recovery Foundation (✅ 완료)

- Canary CDN+Origin 이중 검증
- 자동 Failover (Route53 + WAF + SG)
- DNS Validate + 자동 Rollback
- Manual Failback
- Cross-Account (STS AssumeRole)

---

## Phase 2 — Enterprise Production Ready (✅ 완료)

- Platform / Service Account 분리
- Organizations Discovery
- DynamoDB 4축 상태 모델 + DAL + Stream History
- 보고서 2종 + 알림 18종
- CLI (approve/defer/exclude/status/history)
- Canary Health Sync + Token Rotation
- Terraform Remote State (S3)

---

## Phase 3 — Web Portal (계획)

- API Gateway REST API
- CNAME ↔ ALB 매핑 UI
- Approve/Status 화면
- RBAC (Cognito)

---

## Phase 4 — GitOps Automation (계획)

- DDB Stream → GitOps Lambda
- services/*.json 자동 PR
- GitHub Actions: merge → terraform apply

---

## Phase 5 — AI Ops (비전)

- CDN 장애 예측
- Alarm threshold 자동 튜닝
- 자동 Failback
- ChatOps

---

## 비용 (서비스당)

| 항목 | 1개 | 10개 |
|------|-----|------|
| Canary | $12 | $120 |
| Lambda+SFN+DDB | $7 | $15 |
| S3+SNS+SES | $5 | $5 |
| **합계/월** | **~$24** | **~$140** |
