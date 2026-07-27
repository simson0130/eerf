# 🛡️ EERF

### Enterprise Edge Recovery Platform

**Recover Automatically. Govern Safely.**

3-minute automated recovery when your CDN fails — zero operator intervention.

![Phase](https://img.shields.io/badge/Phase_4-Production_Ready-brightgreen)
![AWS](https://img.shields.io/badge/AWS-Native-FF9900?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python)
![CORF](https://img.shields.io/badge/CORF-Compliant-blue)

| MTTR | Intervention | Architecture | Governance | Scale | Compliance |
|:----:|:----:|:----:|:----:|:----:|:----:|
| **30min → 3min** | **Zero-touch** | **AWS Native** | **DDB SSOT** | **Multi-Account** | **CORF ✅** |

---

## Problem

Your services depend on external CDN (Cloudflare, Akamai, Fastly). When the CDN fails:
- Manual DNS change takes 30 minutes to hours
- Can't distinguish Edge failure vs Origin failure
- Origin exposed without CDN protection layer

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
```

---

## Key Features

| # | Feature | Value |
|---|---------|-------|
| 1 | **Dual-Path Canary** | Edge-only fault isolation |
| 2 | **Transaction Rollback** | Partial failure safe |
| 3 | **Post-Switch Validation** | Auto-rollback if unhealthy |
| 4 | **WAF Auto-Hardening** | Origin protection without CDN |
| 5 | **Governance Pipeline** | Discovery + Human approval |
| 6 | **4-Axis State Model** | CONFIG / GOVERNANCE / OPERATION / HEALTH |
| 7 | **Policy Decision Engine** | DDB rules + criticality + blast radius |
| 8 | **Evidence Immutability** | S3 Object Lock (365d) |
| 9 | **Web Portal (20 pages)** | Full operations without CLI |
| 10 | **CORF Compliant** | 37 MUST items PASS |

---

## Repository Structure

```
eerf/
├── platform/           # Terraform + Lambda source
│   ├── *.tf                # Infrastructure as Code
│   ├── lambda/             # Python Lambda (17 functions)
│   ├── canary/canary.py    # Synthetics handler
│   └── services/*.json     # Per-service config
├── service/             # Service Account (infra + trust roles)
├── portal/              # React Web Portal (20 pages)
├── tools/               # CLI + Operations scripts
└── docs/                # Documentation (numbered folders)
```

---

## Roadmap

| Phase | Focus | Status |
|:---:|:---|:---:|
| **1** | Single service recovery | ✅ |
| **2** | Multi-service governance | ✅ |
| **3** | Web Portal (20 pages + API 27+) | ✅ |
| **4** | Production (Policy+Safety+Evidence+CORF) | ✅ |
| **5** | GitOps pipeline | 📋 Design |
| **6** | Multi-CDN (Cloudflare/Akamai) | 💡 |

---

## Documentation

See [docs/README.md](docs/README.md) for the full documentation map.

---

## License

MIT
