# Security — IAM, WAF, Network 설계

> 최소 권한 + 이중 보호 + 감사 추적.

---

## Cross-Account IAM

| Role | 위치 | 권한 |
|------|------|------|
| eerf-discovery-trust | Service | Route53/ELB/ACM/WAF 읽기 |
| eerf-platform-trust | Service | Route53 변경, WAF 업데이트, SG 변경 |
| eerf-lambda-role | Platform | STS AssumeRole + S3 + SNS + SSM |

---

## WAF 보안 모델

| 상태 | WAF | 방어 주체 |
|------|-----|----------|
| 정상 | COUNT | CDN WAF |
| Failover | BLOCK | AWS WAF (유일한 방어선) |

---

## 네트워크

| 상태 | ALB SG | 보호 |
|------|--------|------|
| 정상 | CF Prefix List only | CDN이 앞단 |
| Failover | + Emergency SG (0.0.0.0/0) | WAF BLOCK이 방어 |

**왜 0.0.0.0/0인데 안전한가?** → WAF BLOCK이 이중 보호.

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `service/iam-platform-trust.tf` | Trust Roles |
| `platform/iam-cross-account.tf` | Platform Roles |
| `service/waf.tf` | WAF + AllowCanaryHealthCheck |
| `service/alb.tf` | SG (CF, Canary, Emergency) |
