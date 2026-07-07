# EERF - Enterprise Edge Recovery Framework

**외부 CDN 장애 시 AWS Origin으로 3분 이내 자동 전환하는 엔터프라이즈 복구 플랫폼**

> CloudFront 기반 데모 환경 (실제 대상: Cloudflare/외부 CDN)

---

## 현재 상태

- **Enterprise Production Ready** (Phase 2 완료)
- 3개 서비스 보호 운영 중 (srv1, srv2, simson)
- DynamoDB 4축 상태 모델 + Stream History
- 보고서 2종 (정기 점검 + Enterprise)
- 통합 알림 (18종) + 감사 증적 체계
- CLI (`eerf status`, `eerf approve`, `eerf history`)

---

## 문서 목록

### 제품

| 문서 | 설명 |
|------|------|
| [executive-summary.md](executive-summary.md) | 비즈니스 가치 (의사결정자 대상) |
| [roadmap.md](roadmap.md) | Phase 1~5 로드맵 |

### 기술 설계

| 문서 | 설명 |
|------|------|
| [architecture.md](architecture.md) | 핵심 아키텍처 (원칙 + 기능 + 상세) |
| [data-model.md](data-model.md) | DynamoDB 4축 + History Table |
| [report-spec.md](report-spec.md) | 보고서 2종 사양 + 비교 |
| [gitops-design.md](gitops-design.md) | Phase 4 GitOps 설계 |
| [adr/](adr/) | Architecture Decision Records (6건) |

### 운영 가이드

| 문서 | 설명 |
|------|------|
| [guides/installation.md](guides/installation.md) | 설치, 배포, 프로젝트 구조 |
| [guides/configuration.md](guides/configuration.md) | 고객별 설정 (필수/Optional/비용) |
| [guides/operations.md](guides/operations.md) | 일일 운영, CLI, 알림 18종, 트러블슈팅 |
| [guides/onboarding.md](guides/onboarding.md) | 신규 서비스 보호 등록 |
| [guides/offboarding.md](guides/offboarding.md) | 서비스 보호 해제 |
| [guides/demo.md](guides/demo.md) | FO/FB 데모 + 시연 가이드 |

### 참고

| 문서 | 설명 |
|------|------|
| [lessons-learned.md](lessons-learned.md) | 설계 교훈 (실전 경험) |

---

## 설계 원칙 (요약)

1. **Dual-Path Detection** — 오탐 방지
2. **Verify-then-Trust** — 검증 실패 시 자동 롤백
3. **Transaction Rollback** — 부분 실패 시 역순 원복
4. **Governance First** — 사람이 통제
5. **Single Source of Truth** — DynamoDB
6. **Audit Everything** — 모든 변경 추적
7. **Manual Failback** — 원복은 사람 판단
