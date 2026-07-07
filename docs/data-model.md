# EERF DynamoDB Data Model

> 4축 상태 모델 운영 중

---

## 원칙

1. **DynamoDB = Single Source of Truth**
2. **S3 = 이력/감사/대용량**
3. **SSM = 시크릿만** (canary token)
4. **DDB Streams → eerf-history** (자동 이력)

---

## 테이블: `eerf-services`

```
PK: SERVICE#{service_key}
SK: CONFIG | GOVERNANCE | OPERATION | HEALTH
```

| PK | SK | 용도 | 주요 속성 |
|----|-----|------|----------|
| SERVICE#{key} | CONFIG | 인프라 + Readiness | account_id, alb_arn, readiness |
| SERVICE#{key} | GOVERNANCE | 관리 분류 | governance_state, operator_id, reason |
| SERVICE#{key} | OPERATION | 운영 구성 | operation_state, last_failover_at |
| SERVICE#{key} | HEALTH | 건강성 | health_state, consecutive_failures |
| ACCOUNT#{id} | STATUS | 계정 스캔 | scan_status, services_count |

---

## GSI

| GSI | PK | 용도 |
|-----|-----|------|
| GSI1 | 축 이름 (CONFIG/GOVERNANCE/...) | 타입별 전체 조회 |
| GSI2 | ACCOUNT#{id} | 계정별 서비스 조회 |

---

## History: `eerf-history`

```
PK: SERVICE#{service_key}
SK: {ISO-timestamp}#{axis}
TTL: 180일
```

| 속성 | 설명 |
|------|------|
| axis | GOVERNANCE / OPERATION / HEALTH |
| previous_state | 이전 상태 |
| new_state | 새 상태 |
| changed_at | UTC ISO 8601 |
| operator_id | 변경 주체 |
| ttl | 180일 후 자동 삭제 |

Stream 필터:
- GOVERNANCE/OPERATION/HEALTH 변경만 (CONFIG 무시)
- 상태값이 실제로 바뀐 경우만
- REMOVE 무시

---

## DAL 사용법

```python
from dal import ServiceRegistry

registry = ServiceRegistry()
config = registry.get_config("app-srv1-1234")
registry.set_operation("app-srv1-1234", "failover")
registry.set_governance("app-srv1-1234", "approved", operator_id="admin")
all_ops = registry.list_by_type("OPERATION")
full = registry.get_service_full("app-srv1-1234")
```

---

## Terraform

```hcl
resource "aws_dynamodb_table" "services" {
  name             = "${var.name_prefix}-services"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "PK"
  range_key        = "SK"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

resource "aws_dynamodb_table" "history" {
  name         = "${var.name_prefix}-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"
  ttl { attribute_name = "ttl"; enabled = true }
}
```

---

## 비용

| 항목 | 월 비용 |
|------|--------|
| 스토리지 | ~$0.03 |
| 읽기/쓰기 | ~$0.12 |
| Stream | 무료 |
| **합계** | **~$1/월** |
