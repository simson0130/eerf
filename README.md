<div align="center">

# 🛡️ EERF

### Enterprise Edge Recovery Platform

**Recover Automatically. Govern Safely.**

3-minute automated recovery when your CDN fails — zero operator intervention.

<br>

![Phase](https://img.shields.io/badge/Phase_4-Production_Ready-brightgreen)
![AWS](https://img.shields.io/badge/AWS-Native-FF9900?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python)
![CORF](https://img.shields.io/badge/CORF-Compliant-blue)

| MTTR | Intervention | Architecture | Governance | Scale | Compliance |
|:----:|:----:|:----:|:----:|:----:|:----:|
| **30min → 3min** | **Zero-touch** | **AWS Native** | **DDB SSOT** | **Multi-Account** | **CORF ✅** |

</div>

---

## Problem

Your services depend on external CDN (Cloudflare, Akamai, Fastly). When the CDN fails:

- 🔴 Manual DNS change takes 30 minutes to hours
- 🔴 Can't distinguish Edge failure vs Origin failure
- 🔴 Origin exposed without CDN protection layer
- 🔴 New services unprotected — onboarding takes days

---

## How EERF Solves It

```
Normal:   User → CDN → ALB → App

Failure:  Canary detects CDN ✗ + Origin ✓ (2 consecutive)
          → Route53: CNAME → ALB (bypass CDN)
          → WAF: COUNT → BLOCK (harden origin)
          → ALB: Emergency SG (allow direct)
          → Wait 45s → DNS Validate (or auto-rollback)

Recovered: User → ALB (direct) → WAF(BLOCK) → App ✓ (< 3 min)

Failback:  Operator confirms CDN back → Manual SFN
           → Route53 → CDN, WAF → COUNT, SG detach
```

---

## Architecture

```
Platform Account (Orchestration)
  Canary / Alarm / Step Functions / Lambda (17 + 3 shared)
  DynamoDB (4-axis state + History)
  SNS / SES / Dashboard / Portal
            |
            | sts:AssumeRole
            v
Service Account(s) (Existing infra — unchanged)
  Route53 / CloudFront / ALB / WAF / EC2
  + Trust Role 2ea only (discovery-trust, platform-trust)
```

---

## Key Features

| # | Feature | Value |
|---|---------|-------|
| 1 | **Dual-Path Canary** | Edge-only fault isolation (no false positives) |
| 2 | **Transaction Rollback** | Partial failure safe — reverse completed steps |
| 3 | **Post-Switch Validation** | Auto-rollback if service unhealthy after switch |
| 4 | **WAF Auto-Hardening** | Origin protection without CDN layer |
| 5 | **Governance Pipeline** | Auto-discovery + Human approval workflow |
| 6 | **4-Axis State Model** | CONFIG / GOVERNANCE / OPERATION / HEALTH |
| 7 | **Policy Decision Engine** | DDB-based rules + criticality + blast radius |
| 8 | **Evidence Immutability** | S3 Object Lock (Governance 365d) |
| 9 | **Web Portal (20 pages)** | Full operations without CLI |
| 10 | **CORF Compliant** | 37 MUST items PASS (Production Ready) |

---

## Roadmap

| Phase | Focus | Status |
|:---:|:---|:---:|
| **1** | 단일 서비스 복구 (Canary+FO/FB+Validate+Rollback) | ✅ |
| **2** | 멀티 서비스 거버넌스 (Discovery+Evaluate+Approve+DDB 4축) | ✅ |
| **3** | 운영 포탈 (React 20페이지 + API 27+ + RBAC) | ✅ |
| **4** | 프로덕션 강화 (Policy+Safety+Evidence+CORF Compliant) | ✅ |
| **5** | 자동화 파이프라인 (GitOps: approve → auto PR → apply) | 📋 설계 완료 |
| **6** | 멀티 CDN 확장 (Cloudflare/Akamai Adapter) | 💡 구상 |
| **7** | 지능형 운영 (AI 예측 + 자동 튜닝 + ChatOps) | 💡 비전 |

> 상세: [docs/roadmap.md](docs/roadmap.md)

---

## Cost

| Services | Monthly |
|----------|--------|
| 1 | ~$24 |
| 10 | ~$140 |
| 50 | ~$650 |

Primary cost driver: Canary ($12/service/month at 1-min interval)

---

## Documentation

| Doc | Content |
|-----|--------|
| [Roadmap](docs/roadmap.md) | Phase 1~7 구현 가이드 |
| [CORF Compliance](docs/corf/compliance.md) | MUST/SHOULD 평가 결과 |
| [CORF MUST Items](docs/corf/must-items.md) | 37개 필수 항목 상세 해설 |
| [Configuration](docs/guides/configuration.md) | Per-customer settings |
| [Operations](docs/guides/operations.md) | CLI, alerts, troubleshooting |

---

## Quick Start

```bash
# 1. Deploy Platform Account
cd platform/
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 2. Deploy Trust Roles in Service Account
# 3. Discovery runs automatically
# 4. Approve discovered services
# 5. Add services/*.json + terraform apply → Protected ✓
```

---

## Design Decisions (ADR)

| # | Decision | Rationale |
|---|----------|----------|
| 001 | Platform / Service separation | Least privilege, multi-account |
| 002 | Discovery + Approval model | Auto-discover, human-approve |
| 003 | Dead Origin simulation | Safe CDN failure testing |
| 004 | Dual-path Canary | Edge-only fault isolation |
| 005 | WAF COUNT→BLOCK | Origin protection without CDN |
| 006 | Manual Failback | Prevent premature rollback |
| 007 | CORF Framework adoption | Lifecycle-based product evaluation |

---

## License

MIT
