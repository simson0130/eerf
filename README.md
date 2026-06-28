# EERF — Enterprise Edge Recovery Platform

> Recover Automatically. Govern Safely.

외부 CDN(Cloudflare/Akamai/Fastly) 장애 시, AWS Origin 인프라로 **3분 이내 자동 전환**하는 엔터프라이즈 운영 플랫폼.

---

## Problem

- CDN 장애 → Origin 정상이어도 서비스 중단
- 수동 DNS 변경 — 복구 30분~수시간
- Edge Failure vs Origin Failure 구분 불가
- 팀마다 다른 복구 절차

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Platform Account                        │
│                                                     │
│  Phase 1: Canary → Alarm → SFN → Lambda (FO/FB)     │
│  Phase 2: Discovery → Diff → Report → Notify         │
│                                                     │
│                  sts:AssumeRole                      │
│                       ↓                             │
├─────────────────────────────────────────────────────┤
│           Service Account(s)                         │
│  Route53 ← DNS / WAF ← COUNT↔BLOCK / ALB ← SG        │
└─────────────────────────────────────────────────────┘
```

정상: 사용자 → Route53 → CDN → ALB → EC2
Failover: 사용자 → Route53 → ALB 직결 → EC2

---

## Features

### Phase 1: Recovery
- Canary CDN+Origin 이중 검증
- 자동 Failover (Route53 + WAF BLOCK + Emergency SG)
- DNS Validate + 자동 Rollback
- Manual Failback
- Cross-Account Multi-Service

### Phase 2: Governance
- Discovery (Organizations 동적 발견)
- Diff Engine (시간별 변경 비교)
- Report Generator (Markdown 보고서)
- Notification (점검보고 + 온보딩 알림 + 삭제 감지)
- CloudWatch 대시보드 (eerf-edge-resilience-center)
- Approval State (Pending → Approved)

---

## Quick Start

```bash
# 1. Service Account에 Trust Role 배포
cd service/
terraform apply

# 2. Platform Account 배포
cd platform/
terraform apply -var-file="terraform.tfvars"

# 3. 자동 스캔 시작 (매 정시)
```

---

## Roadmap

| Phase | 이름 | 주요 기능 | 상태 |
|-------|------|-----------|------|
| 1 | Recovery Foundation | Canary 이중 검증, 자동 FO/FB, DNS Validate + Rollback, Cross-Account | ✅ 완료 |
| 2 | Production Readiness | Discovery, Diff, Report, Notification, Dashboard, Approval | ✅ 완료 |
| 3 | AI Assisted Operations | 서비스 위험도 평가, 온보딩 우선순위 추천, Explainable AI | 📋 계획 |
| 4 | Enterprise Platform | DynamoDB Registry, API Gateway, Web Console, RBAC, 100+ Account | 📋 비전 |

---

## Cost (~$23/month per service)

| Resource | Cost |
|----------|------|
| Lambda (7) | ~$5 |
| Canary | ~$12 |
| Step Functions | ~$1 |
| S3 + CW + SNS | ~$5 |

---

## Documentation

| 문서 | 설명 |
|------|------|
| [Framework Overview](docs/00-framework-overview.md) | 전체 설계 원칙 + 아키텍처 |
| [Executive Summary](docs/01-executive-summary.md) | 비즈니스 효과 요약 |
| [Architecture](docs/02-architecture.md) | 상세 아키텍처 + Cross-Account IAM |
| [Implementation Guide](docs/03-implementation-guide.md) | 배포 가이드 |
| [Test Runbook](docs/04-test-runbook.md) | E2E 테스트 절차 |
| [Operations Guide](docs/06-operations-guide.md) | 운영 가이드 + 대시보드 + 알림 |
| [Roadmap](docs/roadmap.md) | 상세 로드맵 + 비용 |

---

## License

Apache-2.0
