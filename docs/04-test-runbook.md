# EERF 테스트 Runbook — V2 Multi-Account

---

## 테스트 시나리오

| # | 시나리오 | 목적 |
|---|----------|------|
| 1 | Discovery 실행 | 서비스 발견 확인 |
| 2 | 정상 상태 확인 | Canary PASSED, Alarm OK |
| 3 | CDN 장애 시뮬레이션 + 자동 FO | E2E 파이프라인 검증 |
| 4 | FO 후 서비스 정상 확인 | DNS 전환 + WAF BLOCK |
| 5 | Manual Failback | 수동 복원 |
| 6 | Idempotency | 중복 FO 방지 |
| 7 | Cross-Account 권한 | Trust Role 동작 |

---

## Quick Check Tools

```powershell
.\tools\platform-check-status.ps1 -ServiceName app1
.\tools\service-check-status.ps1 -ServiceName app1 -DomainName example.com
```

---

## CDN 장애 시뮬레이션

```bash
terraform apply -var="enable_cloudfront_breaker=true" --auto-approve
```

예상 타임라인: CF 전파 5~10분 → Canary FAIL 2회 → Alarm → SFN → FO 완료

---

## Manual Failback

```powershell
aws stepfunctions start-execution `
  --state-machine-arn arn:aws:states:ap-northeast-2:PLATFORM:stateMachine:eerf-app1-manual-failback `
  --input '{}'
```

---

## E2E Test Flow

```
Phase 1: 준비 (check-status)
Phase 2: 정상 상태 기록
Phase 3: 장애 시뮬레이션 (breaker=true)
Phase 4: 자동 FO 확인
Phase 5: FO 후 서비스 확인
Phase 6: 원복 (breaker=false)
Phase 7: Failback + 정상 복귀 확인
```
