# Governance Pipeline — 보호 사각지대 자동 발견

> 새 서비스 추가 시 자동 알림, 변경 발생 시 자동 추적.

---

## 파이프라인

```
EventBridge(hourly) → Discovery → Diff Engine → Report → Notification
                         ↓              ↓            ↓          ↓
                    Org 전체 스캔   변경 분류     HTML 보고서   SES/Slack
```

---

## 각 Lambda 역할

| Lambda | 역할 |
|--------|------|
| Discovery | Organizations 스캔, Edge CNAME 발견, 스냅샷 생성 |
| Diff Engine | 현재 vs 이전 스냅샷 비교, New/Changed/Deleted 분류 |
| Report Generator | HTML 보고서 생성, 커버리지 % 계산 |
| Notification | SES HTML 메일 + Slack + SNS 발송 |

---

## CloudWatch 대시보드 연동

| 메트릭 | 의미 |
|--------|------|
| TotalDiscovered | 전체 발견 수 |
| ActiveProtected | Approved 수 |
| PendingApproval | 승인 대기 |
| CanaryCoverage | 보호 커버리지 % |
| DriftDetected | 변경 감지 (0/1) |

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `platform/lambda/discovery.py` | Org 스캔 |
| `platform/lambda/diff_engine.py` | 스냅샷 비교 |
| `platform/lambda/report_generator.py` | 보고서 생성 |
| `platform/lambda/notification.py` | 알림 발송 |
| `platform/scan-pipeline.tf` | SFN + EventBridge |
