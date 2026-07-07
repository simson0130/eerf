# EERF 운영 가이드

---

## CLI 명령어

```powershell
eerf --bucket <bucket> status
eerf --bucket <bucket> approve <key> --reason "..."
eerf --bucket <bucket> defer <key> --reason "..."
eerf --bucket <bucket> exclude <key> --reason "..."
eerf --bucket <bucket> reopen <key> --reason "..."
eerf --bucket <bucket> history <key> -n 10
eerf --bucket <bucket> history <key> --axis OPERATION
```

---

## 알림 18종 카탈로그

| AlertType | 트리거 | 대응 |
|-----------|--------|------|
| FAILOVER_SUCCESS | FO Lambda 성공 | CDN 복구 대기 → Failback |
| FAILOVER_ROLLBACK | DNS 검증 실패 | ALB/App 상태 확인 |
| FAILBACK_SUCCESS | FB Lambda 성공 | 추가 조치 없음 |
| FAILBACK_FAILED | FB Lambda 실패 | Route53/WAF/SG 수동 확인 |
| HEALTH_UNHEALTHY | Canary ALARM | 서비스 상태 확인 |
| HEALTH_RECOVERED | Canary OK | 추가 조치 없음 |
| REPORT_CHANGES | 파이프라인 | 보고서 확인 |
| REPORT_NO_CHANGES | 파이프라인 | 확인만 |
| ONBOARDING_NEEDED | 신규 발견 | eerf approve 검토 |
| GOVERNANCE_APPROVED | eerf approve | terraform apply |
| GOVERNANCE_DEFERRED | eerf defer | 추후 재검토 |
| GOVERNANCE_EXCLUDED | eerf exclude | - |
| GOVERNANCE_REOPENED | eerf reopen | eerf approve |
| SFN_FAILED | SFN 실패 | SFN 실행 이력 확인 |
| PIPELINE_ERROR | Lambda 에러 | Lambda 로그 확인 |
| TOKEN_ROTATED | 90일 rotation | 추가 조치 없음 |
| TOKEN_ROTATION_FAILED | rotation 에러 | SSM 수동 확인 |
| HISTORY_WRITE_FAILED | stream_history 에러 | Lambda 로그 확인 |

---

## 대시보드

CloudWatch → Dashboards → eerf-edge-resilience-center

---

## 트러블슈팅

| 증상 | 확인 |
|------|------|
| 이메일 안 옴 | SNS Subscription + SES 인증 |
| 0 services 발견 | Lambda 로그 (AssumeRole) |
| Pipeline 실패 | SFN 실행 이력 |
| Canary FAILED (정상인데) | WAF AllowCanaryHealthCheck 룰 |
| Lambda No changes | `Remove-Item .build\\*.zip -Force` |
