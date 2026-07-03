# EERF Operations Guide

---

## 일일 운영 흐름

```
매 정시 (EventBridge)
  -> Discovery (계정 스캔)
  -> Diff Engine (변경 비교)
  -> Report Generator (HTML 보고서)
  -> Notification (SES 이메일)
```

---

## CLI 명령어

```powershell
# 상태 요약 (4축 표시)
eerf --bucket {AUDIT_BUCKET} status

# 승인 대기 목록
eerf --bucket {AUDIT_BUCKET} list-pending

# 서비스 승인
eerf --bucket {AUDIT_BUCKET} approve "{account_id}:{fqdn}" --reason "보호 대상"

# 보류
eerf --bucket {AUDIT_BUCKET} defer "{account_id}:{fqdn}" --reason "다음 분기"

# 제외
eerf --bucket {AUDIT_BUCKET} exclude "{account_id}:{fqdn}" --reason "내부 서비스"

# 재검토
eerf --bucket {AUDIT_BUCKET} reopen "{account_id}:{fqdn}" --reason "재평가"

# 변경 이력 조회
eerf --bucket {AUDIT_BUCKET} history {service_key}
eerf --bucket {AUDIT_BUCKET} history {service_key} --axis OPERATION -n 5
```

---

## 알림 체계 (alert.py 통합 모듈)

### Recovery
| Subject | 조건 |
|---------|------|
| [EERF] Failover 실행 - {fqdn} | 자동 FO 성공 |
| [EERF] Failover 롤백 - {fqdn} | DNS 검증 실패 후 원복 |
| [EERF] Failback 완료 - {fqdn} | 수동 FB 성공 |
| [EERF] 서비스 이상 감지 - {fqdn} | Canary ALARM |
| [EERF] 서비스 정상 복구 - {fqdn} | Canary OK |

### Governance
| Subject | 조건 |
|---------|------|
| [EERF] 보호 승인 - {fqdn} | eerf approve |
| [EERF] 보호 보류 - {fqdn} | eerf defer |
| [EERF] 보호 제외 - {fqdn} | eerf exclude |
| [EERF] 정기 점검 - 신규 N / 변경 N | 매시간 |

### System
| Subject | 조건 |
|---------|------|
| [EERF] SFN 실행 실패 - {sfn} | SFN FAILED |
| [EERF] 토큰 교체 완료 | 90일 주기 |
| [EERF] 이력 기록 실패 | History Lambda 에러 |

---

## 감사 증적

| 이벤트 | 저장소 | 내용 |
|--------|--------|------|
| CLI 상태 변경 | S3 audit/approval-transitions/ | who, when, what, why |
| Failover | S3 {key}/failover.json | 트리거, 결과, 시간 |
| Failback | S3 {key}/failback.json | operator_id, reason, 결과 |
| 모든 DDB 변경 | eerf-history 테이블 | prev->new, who, when |
| 보고서 발행 | S3 audit/reports/*.json | 메타데이터 |

---

## 트러블슈팅

| 증상 | 확인 |
|------|------|
| 이메일 안 옴 | SNS Subscription 상태 |
| 0 services 발견 | Discovery Lambda 로그 -> AssumeRole 에러 |
| Pipeline 실패 | Step Functions 실행 이력 |
| CLI operator 에러 | AWS 크레덴셜 확인 |
| Canary FAILED (정상인데) | WAF AllowCanaryHealthCheck 룰 확인 |
