# EERF Configuration Guide

> 고객사별 배포 시 커스터마이징 가능한 설정 가이드

---

## 필수 설정

| 변수 | 설명 |
|------|------|
| region | AWS 리전 |
| notification_email | SNS 수신 이메일 |
| org_id | AWS Organization ID |
| ses_from_email | SES 발신 이메일 |
| ses_to_emails | SES 수신 이메일 |

---

## Optional 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| canary_schedule_expression | rate(1 minute) | Canary 실행 주기 |
| alarm_evaluation_periods | 2 | 연속 실패 횟수 |
| failover_wait_seconds | 45 | DNS 전파 대기 |
| governance_schedule_expression | cron(0 * * * ? *) | 파이프라인 주기 |
| enable_enterprise_report | true | Enterprise 보고서 |
| history_ttl_days | 180 | 이력 TTL |
| report_timezone_offset | 9 | KST |
| name_prefix | eerf | 리소스 접두사 |

---

## 비용 영향

| 변경 | 영향 |
|------|------|
| Canary 1분 → 5분 | ~$10/서비스/월 절감 |
| Enterprise Report off | 미미 |
| 파이프라인 일 1회 | 미미 |
