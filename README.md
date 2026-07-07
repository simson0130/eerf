<div align="center">

# 🛡️ EERF

### Enterprise Edge Recovery Platform

**Recover Automatically. Govern Safely.**

3-minute automated recovery when your CDN fails — zero operator intervention.

<br>

![Phase](https://img.shields.io/badge/Phase_5a-Production_Ready-brightgreen)
![AWS](https://img.shields.io/badge/AWS-Native-FF9900?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python)
![Status](https://img.shields.io/badge/Production_Ready-blue)

| MTTR | Intervention | Architecture | Governance | Scale |
|:----:|:----:|:----:|:----:|:----:|
| **30min → 3min** | **Zero-touch** | **AWS Native** | **DDB SSOT** | **Multi-Account** |

</div>

---

## Problem

Your services depend on external CDN (Cloudflare, Akamai, Fastly). When the CDN fails:

- Manual DNS change takes 30 minutes to hours
- Can't distinguish Edge failure vs Origin failure
- Origin exposed without CDN protection layer
- New services unprotected — onboarding takes days

---

## How EERF Solves It

```
Normal:   User → CDN → ALB → App

Failure:  Canary detects CDN ✗ + Origin ✓
          → Route53: CNAME → ALB (bypass CDN)
          → WAF: COUNT → BLOCK (harden origin)
          → ALB: Emergency SG (allow direct)
          → Validate → Success (or auto-rollback)

Recovered: User → ALB (direct) → App ✓ (< 3 min)
```

---

## Architecture

```
Platform Account (Orchestration)
  Canary / Alarm / Step Functions / Lambda
  DynamoDB (4-axis state + History)
  SNS / SES / Dashboard
            |
            | sts:AssumeRole
            v
Service Account(s) (Existing infra)
  Route53 / CloudFront / ALB / WAF / EC2
  + Trust Role 2ea (discovery-trust, platform-trust)
```

---

## Key Features

| # | Feature | Value |
|---|---------|-------|
| 1 | Dual-Path Canary | Edge-only fault isolation |
| 2 | Transaction Rollback | Partial failure safe |
| 3 | Post-Switch Validation | Auto-rollback on failure |
| 4 | WAF Auto-Hardening | Origin protection without CDN |
| 5 | Governance Pipeline | Auto-discovery + Approval workflow |
| 6 | 4-Axis State Model | CONFIG/GOVERNANCE/OPERATION/HEALTH |

---

## Quick Start

```bash
cd platform/
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# Approve discovered services
eerf approve app-example-1111 --reason "Production ready"
```

---

## Documentation

- [Architecture](docs/architecture.md) — Full system design
- [Data Model](docs/data-model.md) — DynamoDB 4-axis
- [Installation](docs/guides/installation.md) — Deployment guide
- [Configuration](docs/guides/configuration.md) — Per-customer settings
- [Operations](docs/guides/operations.md) — Daily ops, CLI, alerts
- [Demo Guide](docs/guides/demo.md) — FO/FB demonstration

---

## License

MIT
