# EERF Architecture - Technical Deep Dive

---

## Core Capabilities (6가지)

### 1.1 Dual-Path Canary

```
CDN X + Origin O -> ALARM  (Edge-only fault -> Failover)
CDN X + Origin X -> ALARM  (전체 장애 -> 알림만)
CDN O            -> OK     (정상)
```

### 1.2 Decision Engine (Step Functions)

```
Alarm -> ExecuteFailover -> Wait(45s) -> ValidateDNS
                                          +-- 성공 -> Complete
                                          +-- 실패 -> Auto-Rollback -> Fail
```

### 1.3 Post-Switch Validation + Auto-Rollback

재시도: 8회 x 15초 = 최대 2분. 실패 시 자동 Failback.

### 1.4 WAF Auto-Hardening

```
정상: User -> CDN(방어) -> ALB -> WAF(COUNT) -> App
FO:   User -> ALB(직접) -> WAF(BLOCK) -> App
```

### 1.5 Governance Pipeline

```
EventBridge(hourly) -> Discovery -> Diff -> Report -> Notification
```

### 1.6 4-Axis State Model + History

```
상태 변경 -> DDB Stream -> stream_history Lambda -> eerf-history
```

---

## 기능별 Flow

### Flow 1: Discovery (매시간)

EventBridge -> Discovery Lambda -> Org 전체 스캔 -> DDB CONFIG 저장 -> Diff -> Report -> SES

### Flow 2: Approval (운영자 수동)

eerf approve -> DDB GOVERNANCE -> Stream -> History -> SNS 알림

### Flow 3: Failover (자동, ~3분)

Canary ALARM -> EventBridge -> SFN -> Failover Lambda
  - Route53: CDN -> ALB
  - WAF: COUNT -> BLOCK
  - SG: Emergency 연결
  - DDB: set_operation("failover") + set_health("unhealthy")
  -> Wait 45s -> DNS Validate -> 성공/롤백

### Flow 4: Failback (수동)

operator -> safe-failback.ps1 -> SFN -> Failback Lambda
  - Route53: ALB -> CDN
  - WAF: BLOCK -> COUNT
  - SG: Emergency 제거
  - DDB: set_operation("standby")

### Flow 5: Health Update (자동)

Canary Alarm ALARM/OK -> EventBridge -> health_update Lambda -> DDB HEALTH

### Flow 6: History (자동)

DDB 변경 -> Stream -> stream_history Lambda -> eerf-history (TTL 180일)

### Flow 7: Report (매시간)

DDB 4축 조회 + S3 diff -> HTML 보고서 -> S3 + SES

---

## 계정 구조

```
Platform Account: Canary, Alarm, SFN, Lambda, DDB, SNS, SES, Dashboard
  | sts:AssumeRole
  v
Service Account(s): Route53, CloudFront, ALB, WAF, EC2 + Trust Role 2개
```

---

## 비용 (서비스 1개 기준)

| 리소스 | 월 비용 |
|--------|--------|
| Lambda | ~$5 |
| SFN | ~$1 |
| Canary | ~$12 |
| DDB | ~$1 |
| S3/CW/SNS/SES | ~$5 |
| **합계** | **~$24** |
