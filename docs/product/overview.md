# EERF - Enterprise Edge Recovery Framework

> **Recover Automatically. Govern Safely. Track Everything.**

---

## What is EERF?

외부 CDN(CloudFront, Cloudflare, Akamai, Fastly) 장애 시, AWS Origin으로 **3분 이내 자동 전환**하는 엔터프라이즈 복구 플랫폼.

단순한 DNS Failover가 아닌 - **감지 -> 판단 -> 전환 -> 검증 -> 보안강화 -> 이력추적**을 하나의 플랫폼으로 표준화합니다.

---

## Core Capabilities (6가지)

| # | 기능 | 한 줄 가치 |
|---|------|----------|
| 1 | **Dual-Path Canary** | Edge만 죽었는지 정확히 판단 (오탐 방지) |
| 2 | **Decision Engine** | 감지 -> 판단 -> 실행 -> 검증을 자동화 |
| 3 | **Post-Switch Validation** | 전환 실패 시 자동 롤백 (안전 보장) |
| 4 | **WAF Auto-Hardening** | CDN 없이도 Origin 즉시 보호 |
| 5 | **Governance Pipeline** | 미보호 서비스 자동 발견 + 변경 추적 |
| 6 | **4-Axis State Model** | 서비스 상태를 4축으로 완전 추적 |

---

## 4축 상태 모델 (DynamoDB)

| 축 | 역할 | 값 | 변경 주체 |
|----|------|-----|----------|
| **GOVERNANCE** | 관리 분류 | discovered / pending / approved / deferred / excluded | 운영자 (CLI) |
| **OPERATION** | 운영 구성 | standby / failover / restoring | 시스템 (Lambda) |
| **HEALTH** | 실시간 건강성 | healthy / degraded / unhealthy / unknown | 시스템 (Canary/Alarm) |
| **CONFIG** | 인프라 사실 | ALB, WAF, SG, Role 등 Readiness | 시스템 (Discovery) |

모든 상태 변경은 자동으로 이력에 기록됩니다 (DynamoDB Stream -> eerf-history).

---

## Lifecycle

```
Discovery -> Approval -> Onboarding -> Monitoring -> Recovery -> Failback
    |           |           |            |           |          |
  자동 발견   운영자 승인   JSON 1개    1분 체크    3분 전환    수동 확인
```

---

## CLI

```
eerf status              - 전체 서비스 4축 상태 표시
eerf approve <key>       - 보호 승인
eerf defer <key>         - 보류
eerf exclude <key>       - 영구 제외
eerf reopen <key>        - 재검토
eerf list-pending        - 승인 대기 목록
eerf history <key>       - 변경 이력 조회
```
