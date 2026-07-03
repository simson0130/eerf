# ADR-006: Manual Failback

## 상태: Accepted

## 결정

Failback은 자동이 아닌 수동으로 실행한다.

## 이유

- CDN 복구 판단을 자동화하면 조기 롤백 위험
- CDN이 불안정하게 복구되는 중에 자동 Failback하면 또 장애
- 운영자가 CDN 정상 확인 후 수동 판단
- safe-failback.ps1: CDN health check N회 성공 후 자동 실행 (반자동)
