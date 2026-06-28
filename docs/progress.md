# EERF Progress Log

---

## 2026-06-27 (Day 2) — Phase 2 Governance 구현 완료

### Completed
- [x] Phase 2 Governance Pipeline 전체 구현 + 배포
- [x] Discovery Lambda 확장: Organizations 동적 발견, 스냅샷 저장, Exclude 연동
- [x] Diff Engine Lambda: 일일 변경 비교 (New/Changed/Deleted/Unchanged/Excluded)
- [x] Report Generator Lambda: Markdown 보고서 생성 + S3 저장
- [x] Notification Lambda: SNS 이메일 (보고서 전문 포함) + Slack Block Kit
- [x] Approval State 모듈: Pending_Approval 자동 부여, best-effort 영속화
- [x] Exclude Services 모듈: exclude-services.yaml 기반 제외
- [x] CloudWatch Metrics 발행: EERF/Governance 네임스페이스
- [x] Step Functions 파이프라인: Discovery → Diff → Report → Notify + ErrorNotify
- [x] EventBridge 스케줄: 6시간 간격 (rate(6 hours))
- [x] CloudWatch 거버넌스 대시보드 (한글 위젯명)
- [x] Terraform IaC: governance.tf (Lambda + SFN + EventBridge + IAM)
- [x] archive_file: source_dir 방식 (공유 모듈 + PyYAML 번들링)
- [x] PyYAML Linux 바이너리 Lambda 패키징
- [x] 운영 가이드 문서 (docs/06-operations-guide.md)
- [x] E2E 검증: 3개 서비스 발견, 보고서 이메일 수신, 대시보드 메트릭 표시
- [x] Python 테스트: 197개 전체 통과
- [x] terraform validate 통과

### Key Decisions
- Governance와 Phase 1 (Canary/Failover)는 독립 동작 — 같은 state에 공존
- Discovery trust role 이름 `eerf-discovery-trust`로 통일
- 보고서/대시보드 용어 통일: 전체 발견 / 관리 중 / 미관리 / 제외 / 구성 미완 / Failover 중 / 스캔 오류
- 대시보드/보고서 한글화

### Remaining
- [ ] Service Account trust role 이름 통일 재배포 (eerf-discovery-trust)
- [ ] 2번째 보호 대상 온보딩 테스트 (app.example.com → tfvars 추가)
- [ ] SES HTML 이메일 (Markdown → HTML 렌더링)
- [ ] Service Status Log Insights 테이블 데이터 확인

---

## 2026-06-26 (Day 1) — Phase 1 Foundation 구현

### Completed
- [x] V2 Multi-Account architecture design (Platform / Service separation)
- [x] Terraform code: platform/ + service/
- [x] Lambda code: failover, failback, dns_validate, discovery
- [x] Canary.js (CDN + Origin dual-path check)
- [x] DNS subdomain delegation: srv1.example.com
- [x] Service Account deploy (VPC, ALB, EC2, WAF, CloudFront, ACM, Route53, Trust Roles)
- [x] Platform Account deploy (Canary, Alarm, EventBridge, SFN, Lambda, Dashboard, SNS, S3 Audit)
- [x] E2E Test: CDN breaker → Auto Failover → DNS to ALB
- [x] E2E Test: Safe Failback → DNS to CloudFront
- [x] Discovery Lambda: 2 accounts scanned
- [x] Tools: service-check-status.ps1, platform-check-status.ps1, safe-failback.ps1
- [x] ADR 6 docs, roadmap, lessons-learned

---

## Next: Phase 3 — Multi-Account 통합 + 운영 최적화

### 핵심 목표
- 서비스마다 Lambda 생성 → **Lambda 1세트 통합** (event 기반 동적 처리)
- Trust Role 이름 통일 (`eerf-discovery-trust`) 전 계정 재배포
- `org_id`만으로 전체 자동 동작 (accounts 명시 불필요)
- SES HTML 이메일 (Markdown → HTML 렌더링)
- Approval CLI 도구 (S3 yaml 직접 수정 → 명령어 기반)

### TODO
- [ ] Lambda 통합: failover/failback/validate를 1개씩으로 (SSM에서 서비스 설정 로드)
- [ ] Trust Role 통일: 모든 Service Account에 `eerf-discovery-trust` 배포
- [ ] Onboarding 자동화: Discovery → Approval → tfvars PR 자동 생성
- [ ] SES HTML 보고서 이메일
- [ ] Slack Block Kit 개선 (도메인 링크, 액션 버튼)
- [ ] services map → JSON 파일 분리 (서비스 50+ 대비)
- [ ] 대시보드 14일 추이 안정화 (period 조정)
- [ ] Cloudflare API 연동 (Proxy Off 자동 전환)
