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

</div>

<br>

```mermaid
flowchart LR
    A["❌ CDN Failure"] -->|Canary detects| B["🧠 Decision Engine"]
    B -->|"CDN ✗ Origin ✓"| C["🔄 Route53 → ALB"]
    C --> D["🛡️ WAF BLOCK"]
    D --> E["✅ Service OK"]
    
    style A fill:#e74c3c,color:#fff
    style B fill:#2d3e50,color:#fff
    style C fill:#3498db,color:#fff
    style D fill:#9b59b6,color:#fff
    style E fill:#27ae60,color:#fff
```

*Total elapsed: < 3 minutes — fully automated, zero operator intervention*

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

## Architecture

```mermaid
graph TB
    subgraph Platform["Platform Account"]
        subgraph Protection["Protection Layer"]
            Canary[Canary<br/>dual-path] --> Alarm[CloudWatch Alarm]
            Alarm --> EB[EventBridge]
            EB --> SFN[Step Functions]
            SFN --> FO[Failover Lambda<br/>Route53 + WAF + SG]
            SFN --> Validate[DNS Validate]
        end
        subgraph Governance["Governance Layer"]
            Schedule[EventBridge hourly] --> Discovery[Discovery<br/>Org scan]
            Discovery --> Diff[Diff Engine]
            Diff --> Report[Report Generator]
            Report --> Notify[Notification<br/>SES + Slack]
        end
    end
    
    subgraph Service["Service Account(s)"]
        R53[Route53]
        WAF[WAF]
        ALB[ALB]
        CF[CloudFront]
    end
    
    FO -->|sts:AssumeRole| R53
    FO -->|sts:AssumeRole| WAF
    FO -->|sts:AssumeRole| ALB
    Discovery -->|sts:AssumeRole| Service
```

---

## Runtime Flow

```
  Normal:     User → CDN → ALB → App        (Canary checks both paths ✓)

  Failure:    Canary: CDN ✗ + Origin ✓ → ALARM
              → Step Functions:
                1. Route53: CNAME → ALB       (bypass CDN)
                2. WAF: COUNT → BLOCK         (harden origin)
                3. ALB: Emergency SG          (allow direct)
                4. Wait 45s → Validate        (health check)
                5. Fail? → auto rollback
              → Notification sent, Audit logged

  Recovered:  User → ALB (direct) → WAF(BLOCK) → App ✓    (< 3 min)

  Failback:   Operator confirms CDN back → Manual SFN
              → Route53 → CF, WAF → COUNT, SG detach → Validate
```

---

## Repository Structure

```
eerf/
├── platform/                    # 🎛️  Orchestration + Governance
│   ├── canary.tf                    # Synthetics canary (dual-path)
│   ├── canary-token.tf              # Token rotation (90-day)
│   ├── failover.tf                  # Failover/Failback Step Functions
│   ├── failover-lambda.tf           # FO/FB/Validate Lambda
│   ├── discovery.tf                 # Service discovery (Organizations)
│   ├── scan-pipeline.tf             # Governance: Diff → Report → Notify
│   ├── dashboard.tf                 # CloudWatch dashboards
│   ├── iam-cross-account.tf         # Cross-account IAM
│   ├── ses.tf                       # SES email delivery
│   ├── services.tf                  # Service config loader
│   ├── ssm-services.tf              # SSM Parameter Store
│   ├── storage.tf                   # S3 audit + SNS
│   ├── lambda/                      # Python Lambda source
│   │   ├── discovery.py             # Organizations cross-account scan
│   │   ├── failover.py              # DNS + WAF + SG automation
│   │   ├── failback.py              # Restore to CDN path
│   │   ├── dns_validate.py          # Post-switch health check
│   │   ├── diff_engine.py           # Snapshot comparison
│   │   ├── report_generator.py      # HTML governance report
│   │   ├── notification.py          # SES + Slack + SNS
│   │   ├── approval_state.py        # Approval state machine
│   │   ├── exclude_services.py      # Exclusion management
│   │   ├── metrics.py               # CloudWatch metrics
│   │   ├── token_rotation.py        # Canary token rotation
│   │   └── onboarding_pr.py         # Auto-PR for new services
│   ├── canary/canary.py             # Synthetics handler
│   └── services/                    # Per-service JSON configs
│
├── service/                     # 🏗️  Service Account (infra + trust)
│   ├── network.tf, alb.tf, waf.tf, cdn.tf, compute.tf
│   ├── dns.tf, acm.tf, dashboard.tf
│   └── iam-platform-trust.tf        # Cross-account trust roles
│
├── tools/eerf-cli/              # 🔧  CLI (approve/defer/exclude)
│
└── docs/                        # 📚  Documentation + ADRs
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
