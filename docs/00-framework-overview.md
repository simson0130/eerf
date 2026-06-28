# AWS External Edge Recovery Framework (EERF) V2

## Enterprise Platform Framework — Multi-Account Architecture

---

## Vision

현대 기업은 Cloudflare, Akamai, Fastly 등 외부 Edge 서비스에 의존합니다.
이들은 CDN, DDoS 방어, WAF, TLS 종단 등 핵심 기능을 제공하지만, 동시에 **운영상 치명적인 단일 장애점(SPOF)**을 형성합니다.

**EERF**는 외부 Edge 서비스에 대한 **감지, 거버넌스, 모니터링, 복구, 검증, 연속 운영**을 AWS 환경 전반에 걸쳐 표준화하는 엔터프라이즈 운영 프레임워크입니다.

---

## Design Principles

1. **Discovery First** — 기존 AWS 인프라에서 후보 서비스를 자동 발견
2. **Approval Before Automation** — 운영자 검토/승인 후 온보딩
3. **Platform/Service Separation** — Platform = 오케스트레이션, Service = 인프라 소유
4. **AWS Native** — Route53, CloudWatch Synthetics, Step Functions, Lambda, WAF, EventBridge
5. **Infrastructure as Code** — Terraform 기반 배포

---

## Recovery Flow

### Failover (Auto)
```
Canary FAIL (CDN만) → Alarm → EventBridge → Step Functions
  → AssumeRole → Route53 CNAME→ALB + WAF BLOCK + Emergency SG
  → DNS Validate → Success / Rollback
```

### Failback (Manual)
```
CDN 복구 확인 → Manual SFN 실행
  → Route53 복원 + WAF COUNT + SG 제거
```

---

## Security Model

| Role | 위치 | 권한 |
|------|------|------|
| Discovery Trust | Service Account | Route53/ELB/ACM/WAF 읽기 |
| Platform Trust | Service Account | Route53 변경, WAF 업데이트, SG 변경 |

---

## Success Metrics

| 지표 | 목표 |
|------|------|
| MTTR | 30분 → 5분 이내 |
| 온보딩 | 수일 → 수분 |
| 복구 일관성 | 100% 표준화 |
| 기존 인프라 영향 | Trust Role만 추가 |

---

Full framework document: See docs/00-framework-overview.md in private repo.
