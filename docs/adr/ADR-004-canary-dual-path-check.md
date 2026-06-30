# ADR-004: Canary 이중 경로 검증

## Status
Accepted

## Context
단순히 CDN 경로만 체크하면 Origin(ALB) 장애 시에도 Failover 트리거 → 의미 없는 전환

## Decision
Canary가 **CDN 경로 + Origin 경로** 두 가지를 동시에 체크:

```
if (!cdn.ok && origin.ok) → FAILED  // Edge만 장애 → FO 트리거
if (!cdn.ok && !origin.ok) → FAILED  // 전체 장애 → 알람만
if (cdn.ok) → PASSED                 // 정상
```

**Failover 트리거 조건: CDN 실패 AND Origin 정상**

## Consequences
- (+) Edge만 죽은 경우를 정확히 식별
- (+) 불필요한 전환 방지
- (-) Canary 로직이 단순 HTTP check보다 복잡

## Notes
- WAF `AllowCanaryHealthCheck` 룰로 Canary 요청은 항상 ALLOW
- `x-canary-token` 헤더로 Canary 식별
