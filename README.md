<div align="center">

# 🛡️ EERF

### Enterprise Edge Recovery Platform

**Recover Automatically. Govern Safely.**

3-minute automated recovery when your CDN fails — zero operator intervention.

<br>

![Phase](https://img.shields.io/badge/Phase_2-Complete-brightgreen)
![AWS](https://img.shields.io/badge/AWS-Native-FF9900?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python)
![Status](https://img.shields.io/badge/Enterprise_Ready-Beta-blue)

<br>

| MTTR | Intervention | Architecture | Governance | Scale |
|:----:|:----:|:----:|:----:|:----:|
| **30min → 3min** | **Zero-touch** | **AWS Native** | **GitOps** | **Multi-Account** |

<br>

<img src="docs/assets/eerf-failover-flow.svg" alt="EERF Failover Flow" width="720">

*CDN Failure → Decision Engine → Route53 Switch → WAF Hardening → Service OK (< 3 min)*

</div>

---

## Quick Start

```bash
# 1. Deploy Platform Account (orchestration + governance)
cd platform/
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 2. Deploy Trust Role in each Service Account
cd ../service/
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 3. Discovery runs automatically (hourly) → email arrives

# 4. Approve discovered services
eerf approve app-example-1111 --reason "Production ready"

# 5. Service is now protected ✓ (Canary + Auto-failover active)
```

**Time to first protection: ~15 minutes**

---

## Why EERF? (vs Traditional DNS Failover)

| | Traditional Route53 Failover | EERF |
|:--|:--|:--|
| **Detection** | Simple health check | Canary cross-validation (CDN + Origin) |
| **Decision** | Binary UP/DOWN | Decision Engine (Edge-only fault isolation) |
| **Recovery** | DNS failover only | DNS + WAF hardening + SG automation |
| **Scope** | Single account | Multi-Account (Organizations) |
| **Governance** | None | GitOps Approval + Audit trail |
| **Visibility** | CloudWatch alarm | Dashboard + Hourly scan + Reports |
| **Rollback** | Manual | Auto-rollback on validation failure |
| **Onboarding** | Manual per-service | Auto-discovery + Approval workflow |

**Route53 Failover solves "is my origin alive?"**
**EERF solves "my CDN is dead, recover the entire path safely."**

---

## Problem

Your services depend on external CDN (Cloudflare, Akamai, Fastly). When the CDN fails:

- 🔴 **Manual DNS change** takes 30 minutes to hours
- 🔴 **Can't distinguish** Edge failure vs Origin failure
- 🔴 **Origin exposed** without CDN protection layer
- 🔴 **No standard procedure** — every team does it differently
- 🔴 **New services unprotected** — onboarding takes days
- 🔴 **No visibility** — changes go undetected

---

## Solution

| Existing Approach | EERF |
|:---|:---|
| DNS Failover (manual) | **Decision Engine** (automated, validated) |
| Manual intervention | **Zero-touch recovery** |
| Single account | **Multi-Account (Organizations)** |
| No governance | **GitOps Approval workflow** |
| Recovery only | **Recovery + Governance Platform** |
| No visibility | **Dashboard + Hourly scan + Reports** |

---

## In Action

<div align="center">

| Edge Resilience Center Dashboard | Governance Report (Email) |
|:---:|:---:|
| <img src="docs/assets/dashboard-screenshot.png" alt="Dashboard" width="380"> | <img src="docs/assets/report-screenshot.png" alt="Report" width="380"> |

*Real operational screens from production deployment*

</div>

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Platform Account                          │
│                                                             │
│  ┌─── Protection Layer ────────────────────────────────┐    │
│  │                                                     │    │
│  │  Canary ──→ Alarm ──→ EventBridge ──→ Step Functions │    │
│  │  (dual-path)  (2/2)                    │            │    │
│  │                              ┌─────────┴──────────┐ │    │
│  │                              │  Failover Lambda   │ │    │
│  │                              │  • Route53 switch  │ │    │
│  │                              │  • WAF COUNT→BLOCK │ │    │
│  │                              │  • Emergency SG    │ │    │
│  │                              │  • DNS Validate    │ │    │
│  │                              └────────────────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─── Governance Layer ────────────────────────────────┐    │
│  │                                                     │    │
│  │  EventBridge (hourly)                               │    │
│  │    → Discovery (Organizations scan)                 │    │
│  │    → Diff Engine (change detection)                 │    │
│  │    → Report Generator (HTML report)                 │    │
│  │    → Notification (SES + Slack + SNS)               │    │
│  │                                                     │    │
│  │  Dashboard: eerf-edge-resilience-center             │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│                    sts:AssumeRole                            │
│                         ↓                                   │
├─────────────────────────────────────────────────────────────┤
│              Service Account(s) — already in production      │
│                                                             │
│  Route53 ← DNS switch        WAF ← COUNT/BLOCK toggle      │
│  ALB     ← Emergency SG      CloudFront (service-owned)    │
└─────────────────────────────────────────────────────────────┘
```

---

## Runtime Flow

```
                    Normal State
                    ───────────
  User → Cloudflare/CF → ALB → App
         Canary checks both paths ✓

                    CDN Failure Detected
                    ───────────────────
  Canary: CDN ✗ + Origin ✓ → ALARM
    → Step Functions triggered
      → 1. Route53: CNAME → ALB          (DNS bypass CDN)
      → 2. WAF: COUNT → BLOCK            (harden origin)
      → 3. ALB: attach Emergency SG      (allow direct access)
      → 4. Wait 45s → DNS Validate       (confirm health)
      → 5. If validate fails → auto rollback
    → SNS/SES notification sent
    → Audit log written to S3

                    Recovery Complete (< 3 min)
                    ─────────────────────────
  User → ALB (direct) → WAF(BLOCK) → App ✓

                    Manual Failback (operator confirms CDN is back)
                    ──────────────────────────────────────────────
  Operator → Manual Failback SFN
    → Route53: CNAME → CloudFront
    → WAF: BLOCK → COUNT
    → ALB: detach Emergency SG
    → Validate → Done
```

---

## Repository Structure

```
eerf/
├── platform/                    # 🎛️  Orchestration + Governance
│   ├── canary.tf                    # Synthetics canary (dual-path check)
│   ├── canary-token.tf              # Token rotation (90-day cycle)
│   ├── failover.tf                  # Failover/Failback Step Functions
│   ├── failover-lambda.tf           # FO/FB/Validate Lambda functions
│   ├── discovery.tf                 # Service discovery (Organizations)
│   ├── scan-pipeline.tf             # Governance: Diff → Report → Notify
│   ├── dashboard.tf                 # CloudWatch dashboards
│   ├── iam-cross-account.tf         # Cross-account IAM roles
│   ├── ses.tf                       # SES email delivery
│   ├── services.tf                  # Service config loader (JSON + tfvars)
│   ├── ssm-services.tf              # SSM Parameter Store registration
│   ├── storage.tf                   # S3 audit + SNS topic
│   ├── lambda/                      # Python Lambda source
│   │   ├── discovery.py                 # Organizations cross-account scan
│   │   ├── failover.py                  # DNS + WAF + SG automation
│   │   ├── failback.py                  # Restore to CDN path
│   │   ├── dns_validate.py              # Post-switch health validation
│   │   ├── diff_engine.py               # Snapshot comparison engine
│   │   ├── report_generator.py          # HTML governance report
│   │   ├── notification.py              # SES + Slack + SNS delivery
│   │   ├── approval_state.py            # Approval workflow state machine
│   │   ├── exclude_services.py          # Exclusion list management
│   │   ├── metrics.py                   # CloudWatch custom metrics
│   │   ├── token_rotation.py            # Canary token rotation
│   │   └── onboarding_pr.py             # Auto-PR for new services
│   ├── canary/
│   │   └── canary.py                # Synthetics handler (CDN + Origin)
│   └── services/                    # Per-service JSON configs
│
├── service/                     # 🏗️  Service Account (infra + trust)
│   ├── network.tf                   # VPC, subnets, NAT
│   ├── alb.tf                       # ALB + security groups
│   ├── waf.tf                       # WAF Web ACL (COUNT mode)
│   ├── cdn.tf                       # CloudFront distribution
│   ├── compute.tf                   # EC2 sample app
│   ├── dns.tf                       # Route53 records
│   ├── acm.tf                       # TLS certificates
│   ├── iam-platform-trust.tf        # Cross-account trust roles
│   └── dashboard.tf                 # Service-level dashboard
│
├── tools/                       # 🔧  Operational scripts
│   └── eerf-cli/                    # CLI for approve/defer/exclude
│
└── docs/                        # 📚  Documentation
    ├── 00-product-overview.md
    ├── 01-executive-summary.md
    ├── 02-architecture.md
    ├── 03-implementation-guide.md
    ├── 04-test-runbook.md
    ├── 05-lessons-learned.md
    ├── 06-operations-guide.md
    └── adr/                         # Architecture Decision Records
```

---

## Key Design Decisions

| # | Decision | Rationale |
|---|----------|----------|
| [ADR-001](docs/adr/ADR-001-platform-service-separation.md) | Platform / Service separation | Least privilege, multi-account scale |
| [ADR-002](docs/adr/ADR-002-discovery-approval-model.md) | Discovery + Approval model | Auto-discover, human-approve |
| [ADR-003](docs/adr/ADR-003-dead-origin-simulation.md) | Dead Origin testing | Safe CDN failure simulation |
| [ADR-004](docs/adr/ADR-004-canary-dual-path-check.md) | Dual-path canary | Only failover when Edge is the problem |
| [ADR-005](docs/adr/ADR-005-waf-count-to-block.md) | WAF auto-hardening | Origin protection without CDN |
| [ADR-006](docs/adr/ADR-006-manual-failback.md) | Manual failback | Prevent premature rollback |

---

## Roadmap

| Version | Milestone | Status |
|---------|-----------|--------|
| v0.1 | CloudFront single-account PoC | ✅ Done |
| v0.2 | Multi-Account + Governance Pipeline | ✅ Done |
| v0.3 | Lambda consolidation + Cloudflare API | 📋 Planned |
| v0.4 | AFT (Account Factory for Terraform) integration | 📋 Planned |
| v0.5 | Route53 ARC / AIOps | 💡 Exploring |

---

## Vision

<div align="center">

| | Today | Tomorrow |
|:--|:--|:--|
| **Scope** | Enterprise Edge Recovery | Enterprise Recovery Platform |
| **Edge** | CloudFront / Cloudflare | Multi-Edge (Akamai, Fastly, ...) |
| **Operations** | Rule-based automation | AI-Assisted Operations |
| **Governance** | Approval workflow | Enterprise Governance (SOC2, ISO) |
| **Integration** | Terraform + CLI | Service Catalog + Portal |

</div>

---

## Contributing

Contributions welcome. Please read the [Architecture doc](docs/02-architecture.md) before submitting PRs.

---

## License

MIT
