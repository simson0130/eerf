# ADR-005: WAF COUNT → BLOCK 자동 전환

## Status
Accepted

## Context
정상 상태에서는 외부 CDN이 DDoS/WAF 방어를 담당. AWS WAF는 모니터링(COUNT) 모드.
Failover 시 CDN이 빠지면 ALB가 인터넷에 직접 노출. AWS WAF가 유일한 방어선.

## Decision
Failover Lambda가 WAF managed rules를 **COUNT → BLOCK** 으로 자동 전환.
`AllowCanaryHealthCheck` 룰은 **항상 ALLOW 유지**.

### 정상 시
```
CDN(DDoS/WAF) → ALB → AWS WAF(COUNT) → App
```

### Failover 시
```
사용자 → ALB → AWS WAF(BLOCK) → App
```

## Consequences
- (+) CDN 보호 없이도 기본 웹 공격 방어
- (+) 자동 전환이므로 수동 개입 불필요
- (+) Failback 시 자동 복원 (BLOCK → COUNT)
- (-) Managed rule 오탐 가능
