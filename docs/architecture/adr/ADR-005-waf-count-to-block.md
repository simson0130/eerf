# ADR-005: WAF COUNT to BLOCK

## 상태: Accepted

## 결정

Failover 시 WAF Managed Rules를 COUNT -> BLOCK으로 자동 전환한다.

## 이유

- CDN이 우회되면 Origin이 직접 노출됨
- WAF BLOCK으로 전환하여 CDN 없이도 공격 차단
- AllowCanaryHealthCheck 룰은 항상 ALLOW 유지
- RateBasedRule은 COUNT 유지 (오탐 최소화)
- Failback 시 BLOCK -> COUNT 자동 복원
