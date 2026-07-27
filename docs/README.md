# EERF Documentation Map

**CORF(Cloud Operations Recovery Framework)의 첨 번째 구현체.**
CDN 장애 시 3분 이내 자동 복구 — Enterprise Edge Recovery Platform.

> Phase 4 Pilot Validated | CORF Compliant ✅ (MUST 37/37) | 2026-07-23

---

## 읽기 가이드

```
┌─ 00-product ────── "이게 뭐고, 왜 필요한가?"         (의사결정자, 2분)
├─ 01-framework ──── "어떤 철학과 원칙으로 만들었나?"   (아키텍트, 10분)
├─ 02-architecture ─ "어떻게 구성되고 작동하나?"       (테크리드, 30분)
├─ 03-operations ─── "어떻게 다루고 관리하나?"         (SRE, 필요시)
├─ 04-engineering ── "어떻게 만들었고 발전시키나?"     (개발자, 필요시)
└─ 05-decisions ──── "왜 이런 선택을 했나?"            (아무나, 참조)
```

---

## 00-product

| # | 문서 | 설명 |
|:-:|------|------|
| 1 | [001-value-proposition.md](00-product/001-value-proposition.md) | 비즈니스 가치 + 현재 수치 |
| 2 | [002-roadmap.md](00-product/002-roadmap.md) | Phase 1~7 구현 순서 |

## 01-framework

| # | 문서 | 설명 |
|:-:|------|------|
| 1 | [011-philosophy.md](01-framework/011-philosophy.md) | CORF 철학 |
| 2 | [012-lifecycle.md](01-framework/012-lifecycle.md) | 7단계 라이프사이클 |
| 3 | [013-principles.md](01-framework/013-principles.md) | 설계 원칙 P1~P13 |
| 4 | [014-policy-logic-separation.md](01-framework/014-policy-logic-separation.md) | 정책 vs 로직 분리 |
| 5 | [015-compliance-standard.md](01-framework/015-compliance-standard.md) | MUST/SHOULD/MAY 평가 |
| 6 | [016-must-items.md](01-framework/016-must-items.md) | 37개 MUST 항목 |
| 7 | [017-poc-to-product.md](01-framework/017-poc-to-product.md) | PoC→Product 절차 |

## 02-architecture

| # | 문서 | 설명 |
|:-:|------|------|
| 1 | [021-system-overview.md](02-architecture/021-system-overview.md) | 5-Layer + Lambda 맵 |
| 2 | [022-state-model.md](02-architecture/022-state-model.md) | DDB 4축 + GSI + DAL |
| 3 | [023-state-transitions.md](02-architecture/023-state-transitions.md) | 상태 전이 규칙 |
| 4 | [024-report-spec.md](02-architecture/024-report-spec.md) | 보고서 2종 생성 로직 |

## 03-operations

| # | 문서 | 설명 |
|:-:|------|------|
| 1 | [031-portal-guide.md](03-operations/031-portal-guide.md) | Portal 메뉴별 워크플로우 |
| 2 | [032-daily-operations.md](03-operations/032-daily-operations.md) | 일일 운영 + 알림 19종 |
| 3 | [033-service-lifecycle.md](03-operations/033-service-lifecycle.md) | 서비스 보호 등록 (5단계) |
| 4 | [034-offboarding.md](03-operations/034-offboarding.md) | 서비스 보호 해제 |
| 5 | [035-configuration.md](03-operations/035-configuration.md) | 고객별 설정 |
| 6 | [036-installation.md](03-operations/036-installation.md) | 설치, 배포 |
| 7 | [037-demo-runbook.md](03-operations/037-demo-runbook.md) | FO/FB 시연 런북 |

## 04-engineering

| # | 문서 | 설명 |
|:-:|------|------|
| 1 | [041-gitops-pipeline.md](04-engineering/041-gitops-pipeline.md) | Phase 5 GitOps 설계 |
| 2 | [042-terraform-modules.md](04-engineering/042-terraform-modules.md) | TF 모듈 분리 설계 |
| 3 | [043-deployment-evidence.md](04-engineering/043-deployment-evidence.md) | 배포 증적 |
| 4 | [044-lessons-learned.md](04-engineering/044-lessons-learned.md) | 14개 설계 교훈 |

## 05-decisions

| ADR | 제목 |
|:---:|------|
| [001](05-decisions/ADR-001-platform-service-separation.md) | Platform/Service 계정 분리 |
| [002](05-decisions/ADR-002-discovery-approval-model.md) | Discovery + Human Approval |
| [003](05-decisions/ADR-003-dead-origin-simulation.md) | Dead Origin 시뮬 |
| [004](05-decisions/ADR-004-canary-dual-path-check.md) | CDN+Origin 이중 Canary |
| [005](05-decisions/ADR-005-waf-count-to-block.md) | WAF COUNT→BLOCK |
| [006](05-decisions/ADR-006-manual-failback.md) | 수동 Failback |
| [007](05-decisions/ADR-007-corf-adoption.md) | CORF 채택 |
