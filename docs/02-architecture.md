# EERF Architecture Document — V2 Multi-Account

---

## 1. 아키텍처 개요

### 정상 경로
```
사용자 → Route53 (CNAME) → CloudFront/Cloudflare → ALB → WAF(COUNT) → EC2
```

### Failover 경로
```
사용자 → Route53 (CNAME 변경) → ALB → WAF(BLOCK) → EC2
```

---

## 2. 계정 구조

### Platform Account (오케스트레이션 전용)
| 구성요소 | 역할 |
|----------|------|
| Discovery Lambda | Cross-Account 서비스 자동 발견 |
| Synthetics Canary | CDN + Origin 경로 모니터링 |
| CloudWatch Alarm | 장애 감지 → EventBridge |
| Step Functions | FO/FB 오케스트레이션 |
| Lambda (FO/FB/Validate) | Cross-Account AssumeRole → 실행 |
| SNS + S3 | 알림 + 감사 로그 |
| Dashboard | 통합 가시성 |

### Service Account(s)
| 구성요소 | EERF 도입 시 변경 |
|----------|------------------|
| Route53, CloudFront, ALB, WAF, SG, EC2 | 변경 없음 |
| **Discovery Trust Role** | **신규 추가** |
| **Platform Trust Role** | **신규 추가** |

---

## 3. Cross-Account IAM

```
Platform (Discovery Lambda) ─AssumeRole→ Service (eerf-discovery-trust, ReadOnly)
Platform (Failover Lambda) ─AssumeRole→ Service (eerf-{svc}-platform-trust, Route53/WAF/SG)
```

---

## 4. Failover Lambda 동작

| # | 동작 | API | 위치 |
|---|------|-----|------|
| 1 | STS AssumeRole | sts:AssumeRole | Platform → Service |
| 2 | Idempotency 체크 | Route53 List | Service |
| 3 | Route53 CNAME 변경 | Route53 Change | Service |
| 4 | WAF COUNT → BLOCK | WAFv2 Update | Service |
| 5 | Emergency SG 연결 | ELB SetSG | Service |
| 6 | 감사 로그 | S3 Put | Platform |
| 7 | 알림 | SNS Publish | Platform |

---

## 5. DNS 설계

| 항목 | 값 |
|------|-----|
| 레코드 | CNAME |
| TTL | 60초 |
| 정상 | CloudFront/Cloudflare DNS |
| FO | ALB DNS |

---

## 6. 멀티 서비스

```hcl
services = {
  "app1" = { account_id = "111111111111", domain_name = "example.com", ... }
  "app2" = { account_id = "111111111111", domain_name = "example.com", ... }
  "api"  = { account_id = "333333333333", domain_name = "api.co.kr", ... }
}
```

각 서비스는 독립된 Canary + Alarm + SFN + Lambda 세트.
