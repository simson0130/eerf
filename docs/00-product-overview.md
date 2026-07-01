# EERF — Enterprise Edge Recovery Framework

> A reusable engineering framework for **discovering, validating, recovering, and governing** edge services in a standardized and automated manner.

---

## What is EERF?

외부 CDN(Cloudflare, Akamai, Fastly) 장애 시, AWS Origin으로 **3분 이내 자동 전환**하는 엔터프라이즈 복구 프레임워크.

단순한 DNS Failover가 아닌 — **감지 → 판단 → 전환 → 검증 → 보안강화 → 감사**를 하나의 프레임워크로 표준화합니다.

---

## Problem

| 현재 | EERF |
|------|------|
| CDN 장애 시 수동 DNS 변경 (30분~수시간) | 자동 감지 → 3분 이내 전환 |
| Edge vs Origin 구분 불가 | CDN + Origin 교차 검증 |
| CDN 보호 벗겨지면 Origin 노출 | WAF 자동 BLOCK + Emergency SG |
| 팀마다 다른 복구 절차 | 표준 워크플로우 (Step Functions) |
| 새 서비스 보호에 수일 | Discovery → 수분 내 온보딩 |
| 전환 후 장애 확대 위험 | 검증 실패 시 자동 롤백 |

---

## Core Capabilities

| # | Capability | Value |
|---|-----------|-------|
| 1 | **Dual-Path Canary** | Edge-only 장애를 정확히 판단 (오탐 방지) |
| 2 | **Decision Engine** | Detect → Decide → Execute → Validate 자동화 |
| 3 | **Post-Switch Validation** | 전환 실패 시 자동 롤백 (안전 보장) |
| 4 | **WAF Auto-Hardening** | CDN 없이도 Origin 즉시 보호 |
| 5 | **Governance Pipeline** | 미보호 서비스 자동 발견 + 변경 추적 |

---

## Framework Lifecycle

```
Discovery → Approval → Onboarding → Monitoring → Recovery → Failback
    ↓           ↓           ↓            ↓           ↓          ↓
  자동 발견   운영자 승인   JSON 1개    1분 체크    3분 전환    수동 확인
```

---

## Roadmap

| Phase | Focus | Status |
|:-----:|:------|:------:|
| 1 | Recovery — 단일 계정 자동 FO/FB | ✅ |
| 2 | Production Ready — Multi-Account + Governance | ✅ |
| 3 | Provider Adapter — Multi-CDN / Multi-Origin | 📋 |
| 4 | AI Assisted — 예측 + 자동 튜닝 | 💡 |
| 5 | Enterprise Platform — Portal + Compliance | 💡 |

---

## Documentation

| Document | Content |
|----------|--------|
| [Executive Summary](01-executive-summary.md) | 비즈니스 가치, CTO 설득용 |
| [Architecture](02-architecture.md) | 코어 기능 상세 + 기술 아키텍처 |
| [Test Runbook](04-test-runbook.md) | E2E 테스트 시나리오 |
| [Operations Guide](06-operations-guide.md) | 운영 가이드 |
| [Components](components/) | 컴포넌트별 Deep dive |
| [ADRs](adr/) | Architecture Decision Records |
