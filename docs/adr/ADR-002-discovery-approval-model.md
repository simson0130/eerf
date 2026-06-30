# ADR-002: Discovery + Approval 모델

## Status
Accepted

## Context
엔터프라이즈 환경에서 보호 대상 서비스를 수동으로 등록하면 누락 발생, 온보딩 지연, 일관성 없음.
동시에, 모든 발견된 서비스를 자동 편입하면 장애 유발 가능.

## Decision
**Discovery → Approval → Onboarding** 3단계 모델 채택:

1. **Discovery**: Lambda가 Cross-Account 스캔으로 외부 Edge CNAME 자동 발견
2. **Approval**: 발견된 매니페스트를 운영자가 검토/승인
3. **Onboarding**: 승인된 서비스를 services map에 추가 → terraform apply로 보호 활성화

## Consequences
- (+) 자동 발견으로 누락 방지
- (+) 거버넌스 보장 (승인 없이 자동 편입 안 됨)
- (+) 준비 상태(Readiness) 자동 판단
- (-) 완전 자동화가 아님 (사람의 승인 필요)

## Alternatives Considered
- **수동 등록만**: 누락 위험
- **완전 자동 온보딩**: 준비 안 된 서비스에 FO → 장애
- **Config Rules 기반**: 복잡도 높고 Custom Rule 유지보수 부담
