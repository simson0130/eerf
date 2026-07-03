# EERF Product Roadmap

---

## Phase 1 - Recovery Foundation (v0.1, 완료)

- Canary CDN+Origin 이중 검증
- 자동 Failover (Route53 + WAF + SG)
- DNS Validate + 자동 Rollback
- Manual Failback
- Cross-Account (STS AssumeRole)

## Phase 2 - Production Ready (v0.2~v0.3, 완료)

- Platform / Service Account 분리
- Discovery (Organizations 동적 발견)
- 통합 Lambda + SSM 동적 조회
- Approval 상태 머신 + CLI
- SES HTML 보고서 + 즉시 알림
- 대시보드

## Phase 5a - Data Layer (v0.4, 완료)

- DynamoDB 4축 상태 모델 (GOVERNANCE/OPERATION/HEALTH/CONFIG)
- DAL 공통 모듈
- DDB Stream -> History 자동 기록
- Canary -> HEALTH 연동
- S3 YAML 의존성 제거
- 통합 알림 모듈 (alert.py)
- Optimistic Locking
- 감사 증적 강화

## Phase 5b - GitOps (계획)

- DDB Stream -> GitOps Lambda -> GitHub PR
- PR merge -> terraform apply
- eerf approve -> 자동 프로비저닝

## Phase 6 - API + Portal (구상)

- API Gateway REST API
- 웹 포탈 (React SPA)
- Cognito 인증 + RBAC

## Phase 7 - ITSM 연동 (구상)

- 외부 결재 시스템 webhook
- requester/approver 분리
- 감사 증적 연동
