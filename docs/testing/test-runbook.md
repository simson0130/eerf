# EERF E2E Test Runbook

---

## 테스트 시나리오

| # | 시나리오 | 목적 |
|---|----------|------|
| 1 | Discovery 실행 | Service Account 스캔 -> 서비스 발견 |
| 2 | 정상 상태 확인 | Canary PASSED, Alarm OK |
| 3 | CDN 장애 시뮬레이션 + 자동 FO | E2E 파이프라인 |
| 4 | FO 후 서비스 정상 확인 | DNS + WAF BLOCK |
| 5 | Manual Failback | 수동 복원 |
| 6 | Idempotency | 중복 FO 방지 |
| 7 | DDB History 확인 | Stream Lambda 동작 |

---

## PoC 검증 스크립트

```powershell
# 1/3: Data Layer 검증 (비파괴)
.\tools\poc-verify-1-data.ps1

# 2/3: Governance Flow 검증
.\tools\poc-verify-2-governance.ps1

# 3/3: FO/FB E2E (CDN 장애 유발)
.\tools\test-fo-fb.ps1
```

---

## 검증 체크리스트

| # | 항목 | 결과 |
|---|------|------|
| 1 | DDB CONFIG 존재 | |
| 2 | DDB GOVERNANCE state + version | |
| 3 | DDB OPERATION state | |
| 4 | DDB HEALTH state | |
| 5 | Canary Alarm <-> HEALTH 일치 | |
| 6 | eerf-history 이력 존재 | |
| 7 | eerf status CLI 4축 표시 | |
| 8 | approve/defer 전이 정상 | |
| 9 | Failover: OPERATION=failover | |
| 10 | Failback: OPERATION=standby | |
| 11 | 알림 이메일 수신 | |
