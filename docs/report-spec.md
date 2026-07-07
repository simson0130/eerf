# EERF Report Specification

---

## 보고서 2종

| 보고서 | Lambda | 대상 | 핵심 질문 |
|--------|--------|------|----------|
| 정기 점검 | report_generator | 운영팀 | "지금 뭐가 바뀌었고, 뭘 해야 하나?" |
| Enterprise | report_enterprise | 경영진 | "전체 보호 수준은?" |

---

## 정기 점검 보고서 (6섹션)

1. 디스커버리 현황 (coverage %)
2. 관리 대상 서비스 (GOVERNANCE/OPERATION/HEALTH/CONFIG)
3. 관리 제외 서비스
4. 계정 현황
5. 변경 이력 (eerf-history 24h)
6. 참고 사항 (4축별 용어집)

---

## Enterprise Report (5섹션)

1. Executive Summary (Coverage, MTTR, High Risk)
2. Compliance Status
3. Recovery Readiness Score (7항목)
4. Recovery History (7일)
5. Service Fleet

---

## 데이터 흐름

```
DDB eerf-services (4축)
DDB eerf-history (이력)
  ├─→ diff_engine.py → changes 수집
  ├─→ report_generator.py → S3 HTML
  ├─→ report_enterprise.py → S3 HTML
  └─→ notification.py → SES 2통
```
