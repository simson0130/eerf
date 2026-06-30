# ADR-003: Dead Origin을 이용한 CDN 장애 시뮬레이션

## Status
Accepted

## Context
CDN 장애를 테스트하려면 실제 CloudFront/Cloudflare 장애를 재현해야 한다.

## Decision
CloudFront의 Origin을 `dead-origin.invalid`로 변경하여 CDN 경로가 502를 반환하도록 시뮬레이션.

```hcl
variable "enable_cloudfront_breaker" {
  type    = bool
  default = false
}

origin {
  domain_name = var.enable_cloudfront_breaker ? "dead-origin.invalid" : aws_lb.app.dns_name
}
```

## Consequences
- (+) DNS는 정상 (CloudFront DNS resolve 가능)
- (+) CloudFront가 502 반환 → 현실적 CDN 경로 장애 모사
- (+) Terraform variable 하나로 활성/비활성 제어
- (-) CloudFront 배포 전파 5~10분 대기 필요

## Alternatives Considered
| 방식 | 문제 |
|------|------|
| CloudFront disable | DNS resolve 실패 가능, 비현실적 |
| ALB listener rule (503) | CDN 캐시 영향, Origin도 503 |
| WAF block all | Origin 장애와 동일 |
| **Dead origin** ✅ | DNS 정상, CF가 502, Origin 정상 → 정확한 Edge 장애 모사 |
