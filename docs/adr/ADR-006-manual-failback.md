# ADR-006: 수동 Failback (자동 Failback 미채택)

## Status
Accepted

## Context
Failover는 자동이다. Failback도 자동으로 할 수 있을까?

문제: FO 후 Route53이 ALB를 가리키므로, Canary가 CDN 경로를 체크하면 ALB를 통해 200 반환 → "정상"으로 오판 → 자동 FB 트리거 → CDN 아직 미복구 → 장애 재발

## Decision
Failback은 **수동**으로 한다. 운영자가 CDN 복구를 확인한 후 Manual Failback Step Functions를 실행.

```
CDN 장애 → 자동 FO → 운영자가 CDN 복구 확인 → 수동 FB SFN 실행
```

## Consequences
- (+) 잘못된 Failback으로 인한 장애 재발 방지
- (+) Step Functions으로 표준화된 절차
- (-) 완전 자동화가 아님

## Future (V5 검토)
- CDN 복구 전용 Canary: FO 후에도 CDN 직접 경로를 별도 체크
- 조건부 자동 Failback: CDN 복구 Canary가 N회 연속 성공 시 자동 FB

## Alternatives Considered
- **자동 Failback (Alarm OK 시)**: FO 후 Canary가 ALB 경유로 PASSED → 오판
- **타이머 기반 (30분 후)**: CDN 복구 시간 예측 불가
- **Provider API 체크**: Provider 종속, API 장애 시 판단 불가
