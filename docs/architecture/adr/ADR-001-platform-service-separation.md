# ADR-001: Platform / Service Account 분리

## 상태: Accepted

## 결정

EERF 플랫폼(오케스트레이션)과 Service(기존 운영 인프라)를 별도 AWS 계정으로 분리한다.

## 이유

- 최소 권한 원칙: Platform은 필요한 순간만 AssumeRole
- 멀티 계정 확장: Service Account N개에 독립 적용
- 감사: CloudTrail에서 Cross-Account 접근 명확히 추적
- 장애 격리: Platform 장애가 Service에 영향 안 줌
