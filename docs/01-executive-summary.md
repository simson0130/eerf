# EERF Executive Summary — V2 Multi-Account

## AWS External Edge Recovery Framework

---

## 한 줄 요약

외부 CDN(Cloudflare/Akamai/Fastly) 장애 시, AWS Origin 인프라로 **3분 이내 자동 전환**하는 엔터프라이즈 운영 프레임워크. 멀티 어카운트 환경에서 기존 운영 중인 서비스를 무중단으로 보호.

---

## 왜 필요한가

| 현재 | EERF 적용 후 |
|------|-------------|
| CDN 장애 시 수동 DNS 변경 (30분~수시간) | 자동 감지 → 자동 전환 (목표 3분 이내) |
| 팀마다 다른 복구 절차 | 표준화된 워크플로우 |
| 야간/주말 온콜 필수 | 24/7 무인 자동 대응 |
| Edge 장애 vs Origin 장애 구분 불가 | CDN+Origin 교차 검증으로 정확한 판단 |
| 새 서비스 보호에 수일 | Discovery → 수분 내 온보딩 |
| 단일 계정 한계 | 멀티 어카운트 확장 |

---

## 핵심 차별점

### 1. Discovery → Approval → Onboarding
기존 운영 중인 서비스를 **자동 발견 → 승인 → 자동 프로비저닝**. 기존 인프라 무중단.

### 2. Platform / Service 분리
Platform은 오케스트레이션만. CloudFront, ALB, WAF는 서비스 팀 소유 유지.

### 3. Edge만 죽었을 때만 동작
CDN 경로 실패 AND Origin 정상일 때만 Failover. 불필요한 전환 방지.

### 4. Cross-Account 최소 권한
STS AssumeRole로 필요한 순간에만 임시 권한 획득. 감사 추적 보장.

---

## 비즈니스 효과

| 지표 | Before | After |
|------|--------|-------|
| MTTR | 30분~수시간 | **5분 이내** |
| 인적 개입 | 필수 | 불필요 |
| 서비스 온보딩 | 수일 | 수분 |
| 기존 인프라 영향 | - | Trust Role만 추가 (무중단) |
| 계정 확장 | 단일 | 멀티 어카운트 |
