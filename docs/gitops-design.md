# EERF Phase 4 — GitOps PR 자동화 설계

> 상태: 계획 (Phase 3 Web Portal 이후)

---

## 목표

approve 실행 → JSON 자동 생성 → PR → merge → terraform apply

---

## 흐름

```
eerf approve {key}
  → DDB GOVERNANCE = approved
  → DDB Stream 감지
  → GitOps Lambda: CONFIG 읽기 → JSON 생성 → GitHub PR
  → [운영자: PR merge]
  → GitHub Actions: terraform apply
  → Canary/SFN 활성화
```

---

## 구현 항목

1. GitOps Lambda (DDB Stream → PR 생성)
2. DDB CONFIG 기반 JSON 생성
3. GitHub Actions (OIDC 인증)
4. Idempotency (기존 PR 체크)

---

## 선행 조건

- Phase 3 (Web Portal) 완료
- GitHub Actions OIDC 설정
- GitHub token SSM 저장
