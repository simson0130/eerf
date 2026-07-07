# EERF Executive Summary

## 한 줄 요약

외부 CDN(Cloudflare/Akamai/Fastly) 장애 시, AWS Origin 인프라로 **3분 이내 자동 전환**하는 엔터프라이즈 운영 프레임워크.

---

## 비즈니스 효과

| 지표 | Before | After |
|------|--------|-------|
| MTTR | 30분~수시간 | **5분 이내** |
| 인적 개입 | 필수 | 불필요 |
| 서비스 온보딩 | 수일 | 수분 |
| 기존 인프라 영향 | - | Trust Role만 추가 (무중단) |

---

## 핵심 차별점

1. **Discovery → Approval → Onboarding** — 자동 발견 + 인간 승인
2. **Platform / Service 분리** — 최소 권한
3. **Edge만 죽었을 때만 동작** — Dual-path Canary
4. **Cross-Account 최소 권한** — STS AssumeRole

---

## 현재 상태

- Enterprise Production Ready (Phase 2 완료)
- 3개 서비스 보호 운영 중
- DynamoDB 4축 + Stream History
- 보고서 2종 + 알림 18종
- CloudFront 기반 데모 (실제 대상: Cloudflare)

---

## 로드맵

| 버전 | 핵심 기능 | 상태 |
|------|-----------|------|
| v0.1~v0.4 | Recovery + Governance + DDB SSOT | ✅ 완료 |
| v0.5 | Web Portal + GitOps | 계획 |
| v1.0 | AI Ops + Multi-CDN | 비전 |
