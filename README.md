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

| Phase | 내용 | 상태 |
|-------|------|------|
| 1 | Recovery Foundation | ✅ |
| 2 | Production Readiness | ✅ |
| 3 | AI Assisted Operations | 📋 |
| 4 | Enterprise Platform | 📋 |

---

## Cost (~$23/month per service)

| Resource | Cost |
|----------|------|
| Lambda (7) | ~$5 |
| Canary | ~$12 |
| Step Functions | ~$1 |
| S3 + CW + SNS | ~$5 |

---

## License

Apache-2.0
