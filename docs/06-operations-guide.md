# EERF — 운영 가이드

## 1. 거버넌스 파이프라인 개요

매 1시간마다 자동 실행되는 거버넌스 파이프라인이 다음을 수행합니다:

```
EventBridge (rate 1 hour)
  → Discovery (서비스 발견)
  → Diff Engine (변경 비교)
  → Report Generator (보고서 생성)
  → Notification (알림 발송)
```

---

## 2. 알림 체계

| 알림 종류 | 발송 조건 | 메일 제목 예시 |
|-----------|-----------|----------------|
| 정기 점검 보고 (변경 없음) | 항상 | `[EERF] 2026-06-28 10시 점검 보고 - 신규 0 / 변경 0 / 삭제 0` |
| 정기 점검 보고 (변경 있음) | 변경 감지 시 | `[EERF] 2026-06-28 10시 점검 보고 - 신규 1 / 변경 0 / 삭제 0` |
| 온보딩 필요 | 승인 대기 서비스 있을 때 | `[EERF] 2026-06-28 10시 온보딩 필요 - 1개 서비스` |
| ⚠️ 삭제 감지 | 서비스가 사라졌을 때 | `[EERF] 2026-06-28 ⚠️ 서비스 삭제 감지 — 1개` |
| ❌ 파이프라인 에러 | 실행 실패 시 | `[EERF] ❌ Governance Pipeline Error` |

### 온보딩 필요 메일 내용
- 승인 대기 서비스 목록 (FQDN + 계정 ID)
- terraform.tfvars.shared에 복사할 HCL snippet 포함

### 삭제 감지 메일 내용
- 사라진 서비스 목록
- 의도된 삭제 vs 비정상 삭제 구분 가이드

---

## 3. 대시보드 (eerf-edge-resilience-center)

```
CloudWatch → Dashboards → eerf-edge-resilience-center
```

### 상단 위젯 (실시간 현황)
| 위젯 | 의미 | 정상 |
|------|------|------|
| 전체 발견 | Discovery가 찾은 총 서비스 수 | N개 |
| 관리 중 | Approved + canary 배포된 서비스 | approval-state에서 Approved |
| 미관리 | 발견됐으나 아직 보호 안 된 서비스 | 0이면 이상적 |
| 제외 | exclude-services.yaml로 의도적 제외 | — |
| 구성 미완 | ALB/WAF 미연결 (review_required) | 0이면 이상적 |
| Failover 중 | 현재 장애 전환 상태인 서비스 | 0이면 정상 |
| 스캔 오류 | trust role assume 실패 계정 수 | 낮을수록 좋음 |

### 하단 위젯
| 위젯 | 설명 |
|------|------|
| 보호 커버리지 (%) | 관리 / (전체 - 제외) × 100 |
| 서비스 인벤토리 추이 (14일) | 일별 서비스 수 추이 |
| 거버넌스 파이프라인 실행 | 시작/성공/실패/타임아웃 |
| 서비스 상태 (최근 스캔) | 서비스별 상세 현황 테이블 |

---

## 4. 서비스 온보딩 절차

### 4.1 온보딩 메일 수신

메일에 포함된 HCL snippet 확인:
```hcl
  "app" = {
    account_id             = "222222222222"
    domain_name            = "example.com"
    app_subdomain          = "app"
    ...
  }
```

### 4.2 사전 확인
- [ ] 해당 계정에 `eerf-discovery-trust` role 존재 확인
- [ ] 해당 계정에 `eerf-{svc_key}-platform-trust` role 존재 확인
- [ ] readiness = `ready` 확인 (ALB + WAF 연결)

### 4.3 terraform.tfvars.shared 수정

`services` 맵에 HCL snippet 추가. **service key 네이밍 규칙** 참고 (아래 섹션).

### 4.4 배포

```powershell
cd platform
Remove-Item ".build\*.zip" -Force
terraform plan -var-file="terraform.tfvars.shared"   # 변경 확인
terraform apply -var-file="terraform.tfvars.shared"  # 적용
```

자동 생성되는 리소스:
- CloudWatch Synthetics Canary
- CloudWatch Alarm
- EventBridge Rule → Step Functions 연결
- Failover / Failback Step Functions

### 4.5 승인 상태 변경

S3의 approval-state.yaml에서 해당 서비스를 `Approved`로 변경:

```yaml
  "222222222222:app.example.com":
    status: Approved
    operator_id: operator-1
    timestamp: "2026-06-27T10:00:00Z"
    reason: "온보딩 완료 - canary 배포됨"
```

업로드:
```powershell
aws s3 cp approval-state.yaml s3://eerf-audit-BUCKET_ID/approval-state.yaml
```

---

## 5. 서비스 제거

### 5.1 exclude-services.yaml로 제외 (Discovery에서만 숨김)

```yaml
version: "1.0"
services:
  - account_id: "222222222222"
    fqdn: "wallboard.example.com"
    reason: "Internal service - no CDN protection needed"
```

```powershell
aws s3 cp exclude-services.yaml s3://eerf-audit-BUCKET_ID/exclude-services.yaml
```

### 5.2 services 맵에서 제거 (canary/failover 삭제)

`terraform.tfvars.shared`에서 해당 서비스 블록 삭제 후 배포:

```powershell
terraform plan -var-file="terraform.tfvars.shared"   # destroy 확인
terraform apply -var-file="terraform.tfvars.shared"
```

⚠️ Canary, Alarm, Failover SFN이 모두 삭제됩니다.

---

## 6. 네이밍 컨벤션

### 6.1 services 맵 key (terraform.tfvars.shared)

```
{subdomain}-{domain_short}-{account_last4}
```

예시:
| 서비스 | Key |
|--------|-----|
| app.srv1.example.com (111111111111) | `app-srv1-1111` |
| app.example.com (222222222222) | `app-example-2222` |
| api.partner.co.kr (123456789012) | `api-partner-9012` |

### 6.2 AWS 리소스 네이밍

| 리소스 | 패턴 | 예시 | 제한 |
|--------|------|------|------|
| Canary | `{prefix}-{svc_key}` | `eerf-app-srv1-1111` | 21자 |
| Alarm | `{prefix}-{svc_key}-alarm [{fqdn}]` | `eerf-app-srv1-1111-alarm [app.srv1.example.com]` | 256자 |
| Failover SFN | `{prefix}-{svc_key}-failover` | `eerf-app-srv1-1111-failover` | — |
| Failback SFN | `{prefix}-{svc_key}-failback` | `eerf-app-srv1-1111-failback` | — |

### 6.3 21자 제한 계산 (Canary)

```
eerf- (5) + svc_key (최대 16자)
```

### 6.4 IAM Trust Role 이름 (Service Account)

| Role | 이름 | 용도 |
|------|------|------|
| Discovery Trust | `eerf-discovery-trust` | 서비스 발견 (읽기 전용) |
| Platform Trust | `eerf-{svc_key}-platform-trust` | Failover 실행 (Route53/WAF/SG 변경) |

---

## 7. 수동 파이프라인 실행

```
AWS Console → Step Functions → eerf-governance-pipeline → Start execution
```

Input:
```json
{
  "org_id": "o-XXXXXXXXXX",
  "accounts": [
    {"account_id": "111111111111", "role_arn": "arn:aws:iam::111111111111:role/eerf-discovery-trust", "region": "ap-northeast-2"}
  ],
  "bucket": "eerf-audit-BUCKET_ID"
}
```

---

## 8. S3 산출물

| 경로 | 내용 | 주기 |
|------|------|------|
| `snapshots/YYYY-MM-DD/HH-00.json` | 서비스 인벤토리 스냅샷 | 매 실행 |
| `diffs/YYYY-MM-DD/HH-00.json` | 전일 대비 변경사항 | 매 실행 |
| `reports/YYYY-MM-DD/HH-00.md` | Markdown 보고서 | 매 실행 |
| `approval-state.yaml` | 서비스 승인 상태 | 변경 시 자동 |
| `exclude-services.yaml` | 제외 서비스 목록 | 수동 관리 |

---

## 9. Terraform 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enable_governance_pipeline` | 거버넌스 파이프라인 활성화 | `true` |
| `governance_schedule_expression` | 실행 주기 | `rate(1 hour)` |
| `slack_webhook_url` | Slack Webhook (빈 문자열이면 비활성) | `""` |
| `org_id` | AWS Organization ID | — |
| `notification_email` | SNS 알림 수신 이메일 | — |

---

## 10. 트러블슈팅

| 증상 | 확인 |
|------|------|
| 메일 안 옴 | SNS → eerf-notify → Subscription 상태 확인 |
| 0 services 발견 | CW Logs `/aws/lambda/eerf-discovery` → AssumeRole 에러 |
| Pipeline 실패 | Step Functions → 실행 이력 → 실패 스텝 Error/Cause |
| 대시보드 빈 값 | 5분 대기, CW Logs에서 "Failed to publish CloudWatch metrics" 검색 |
| 숫자 불일치 | Report Generator가 단일 소스 — 다음 실행까지 대기 |
