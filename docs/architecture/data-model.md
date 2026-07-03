# EERF DynamoDB Data Model

> 4축 상태 모델 운영 중

---

## 원칙

1. DynamoDB = 운영 상태 Single Source of Truth
2. S3 = 이력/감사/대용량 데이터
3. SSM = 시크릿만
4. DynamoDB Streams -> eerf-history (자동 이력)

---

## 메인 테이블: eerf-services

```
PK: SERVICE#{service_key}
SK: CONFIG | GOVERNANCE | OPERATION | HEALTH
```

| SK | 용도 | 주요 속성 |
|----|------|----------|
| CONFIG | 인프라 사실 + Readiness | account_id, alb_arn, readiness |
| GOVERNANCE | 관리 분류 | governance_state, previous_state, version, operator_id |
| OPERATION | 운영 구성 | operation_state, previous_state, last_failover_at |
| HEALTH | 건강성 | health_state, previous_state, consecutive_failures |

GSI1: 타입별 전체 조회 (GSI1PK=타입, GSI1SK=SERVICE#key)
GSI2: 계정별 조회 (GSI2PK=ACCOUNT#id, GSI2SK=SERVICE#key)

---

## History 테이블: eerf-history

```
PK: SERVICE#{service_key}
SK: {timestamp}#{axis}
```

| 속성 | 설명 |
|------|------|
| axis | GOVERNANCE / OPERATION / HEALTH |
| previous_state | 이전 상태값 |
| new_state | 새 상태값 |
| changed_at | UTC ISO 8601 |
| operator_id | 변경 주체 |
| ttl | 180일 후 자동 삭제 |

Stream 필터: CONFIG 무시, 상태 동일하면 skip

---

## DAL 사용법

```python
from dal import ServiceRegistry
registry = ServiceRegistry()

registry.get_config("app-srv1-6693")
registry.set_operation("app-srv1-6693", "failover")
registry.set_health("app-srv1-6693", "unhealthy", consecutive_failures=3)
registry.list_failover_services()
registry.get_service_full("app-srv1-6693")  # 4축 한번에
```
