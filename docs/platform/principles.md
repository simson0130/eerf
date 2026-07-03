# Recovery Automation Platform - 설계 원칙

---

## 개요

이 문서는 Recovery Automation Platform의 설계 원칙을 정의합니다.
EERF(Enterprise Edge Recovery Framework)는 이 원칙을 적용한 첫 번째 제품으로,
CDN 장애 자동 복구 시나리오를 구현합니다.

동일한 원칙으로 RDS Failover, Region DR, Container Recovery 등
다양한 장애 복구 시나리오를 표준화할 수 있습니다.

---

## 7 Principles

| # | 원칙 | 설명 |
|---|------|------|
| 1 | Dual-Path Detection | 장애 지점을 2개 이상 경로로 교차 검증하여 오탐 방지 |
| 2 | Verify-then-Trust | 복구 행위 후 반드시 검증. 검증 실패 시 자동 롤백 |
| 3 | Transaction Rollback | 복구는 원자적(all-or-nothing). 부분 실패 시 완료된 단계 역순 원복 |
| 4 | Governance First | 자동화 범위를 사람이 통제. 모르는 대상에 함부로 조치하지 않음 |
| 5 | Single Source of Truth | 상태를 한 곳에서 관리. 여러 곳에 흩어지면 정합성 깨짐 |
| 6 | Audit Everything | 모든 상태 변경과 운영자 행위를 추적. 증적 없으면 신뢰 불가 |
| 7 | Manual Failback | 자동 복구는 하되, 원복 판단은 사람에게 위임 (조기 롤백 방지) |

---

## Recovery Loop (공통 패턴)

모든 Recovery 시나리오는 동일한 루프를 따릅니다:

```
[감지] -> [판단] -> [실행] -> [검증] -> [알림] -> [이력]
   ^                                     |
   +---------- 실패 시 롤백 <-----------+
```

| 단계 | 책임 | 실패 시 |
|------|------|--------|
| 감지 | 이중 경로로 장애 확인 | 오탐이면 무시 |
| 판단 | 복구 실행 조건 충족 여부 | 조건 미충족이면 알림만 |
| 실행 | 인프라 변경 (DNS, WAF, SG 등) | 부분 실패 시 롤백 |
| 검증 | 전환 결과 확인 (HTTP, DNS) | 검증 실패 시 자동 롤백 |
| 알림 | 운영자에게 상태 전달 | 알림 실패해도 복구는 유지 |
| 이력 | 모든 변경 자동 기록 | 이력 실패해도 복구는 유지 |

---

## 시나리오 확장 구조

```
recovery-platform/
  core/              <- 공통 프레임워크 (재사용)
    detection        이중 경로 감지 패턴
    decision_engine  오케스트레이션 템플릿
    validator        전환 후 검증 패턴
    rollback         트랜잭션 롤백 패턴
    state_model      4축 상태 모델 (DAL)
    alert            통합 알림
    audit            감사 증적

  scenarios/         <- 시나리오별 구현
    cdn-failover/    EERF (현재 제품)
    rds-failover/    DB 복구
    region-failover/ 리전 DR
    container-failover/ ECS/EKS 복구

  governance/        <- 공통 거버넌스
    discovery        대상 자동 발견
    approval         승인 워크플로우
    report           커버리지 보고
```

각 시나리오는 공통 인터페이스를 구현:

```python
class RecoveryScenario:
    def detect(self) -> bool         # 장애 감지
    def decide(self) -> bool         # 실행 여부 판단
    def execute(self) -> Result      # 복구 실행
    def validate(self) -> bool       # 검증
    def rollback(self) -> None       # 원복
```

---

## 5-Stage Maturity Model

| Stage | 이름 | 핵심 질문 | 산출물 |
|:-----:|------|----------|--------|
| 1 | Proof | 핵심 메커니즘이 동작하는가? | 동작하는 PoC |
| 2 | Operate | 실환경에서 운영할 수 있는가? | 멀티 환경, 자동화, CLI |
| 3 | Protect | 장애와 실수에 안전한가? | 롤백, 동시성 보호, 알림 |
| 4 | Trust | 조직이 의존할 수 있는가? | 데이터 정합성, 이력, 감사, 문서 |
| 5 | Scale | 사람 없이 성장하는가? | GitOps, 포탈, API, 자율 운영 |

---

## EERF의 위치

EERF는 이 원칙을 적용한 첫 번째 제품이며, 현재 Stage 4 수준입니다.

```
Stage 1 Proof    ---- 완료 (v0.1)
Stage 2 Operate  ---- 완료 (v0.2~v0.3)
Stage 3 Protect  ---- 완료 (v0.3)
Stage 4 Trust    ---- 완료 (v0.4)
Stage 5 Scale    ---- 로드맵 (Phase 5b~7)
```
