# ADR-003: Dead Origin Simulation

## 상태: Accepted

## 결정

CDN 장애 시뮬레이션을 CloudFront Origin을 dead-origin.invalid로 변경하는 방식으로 한다.

## 이유

- 실제 CDN을 내리지 않고 Edge 장애만 시뮬레이션
- Origin 변경 -> CF 전파 5~10분 -> Canary 감지 -> Failover E2E 검증
- terraform variable (`enable_cloudfront_breaker`) 하나로 제어
