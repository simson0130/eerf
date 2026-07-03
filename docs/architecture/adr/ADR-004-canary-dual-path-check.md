# ADR-004: Dual-Path Canary

## 상태: Accepted

## 결정

Canary가 CDN 경로와 Origin 경로를 동시에 체크한다.

## 이유

- CDN만 체크하면 Origin도 죽었을 때 Failover가 무의미
- `CDN X + Origin O` 일 때만 Failover 실행 (Edge-only fault)
- `CDN X + Origin X` 일 때는 알림만 (전체 장애, FO 불필요)
- x-canary-token 헤더로 WAF BLOCK 상태에서도 검증 통과
