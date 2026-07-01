# DNS Validate — Post-Switch Safety Net

> "Failover를 해도 안전하다"는 보장을 제공하는 컴포넌트.

---

## 왜 필요한가

| 이게 없으면 | 이게 있으면 |
|------------|----------|
| Route53 전파 안 됐는데 "성공" | 실제 resolve 확인 후 판단 |
| ALB 응답 못 하는데 모름 | HTTPS 200 확인 |
| WAF가 정상 트래픽 차단 | canary-token 우회 검증 |
| **Failover가 장애를 더 키움** | **실패 시 자동 원복** |

---

## 검증 항목

| 항목 | 목적 |
|------|------|
| DNS Resolve (FQDN → IP) | Route53 전파 완료 확인 |
| Route53 API Fallback | Lambda DNS 캐시 우회 |
| HTTPS 200 응답 | ALB + App 실제 정상 확인 |
| x-canary-token 헤더 | WAF BLOCK에서도 검증 가능 |

---

## 재시도 + 롤백

```
재시도: 8회 × 15초 = 최대 2분
  → 성공: Failover 완료 (전체 < 3분)
  → 실패: 자동 Failback (원래 상태 복원)
```

**이것이 EERF와 단순 DNS Failover의 핵심 차이점.**

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `platform/lambda/dns_validate.py` | Lambda 소스 |
| `platform/failover.tf` | SFN Retry/Catch 정의 |

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| DNS resolve 실패 | Lambda DNS 캐시 | Route53 API fallback 확인 |
| Health check timeout | Target unhealthy | Target Group 확인 |
| 403 응답 | WAF 차단 | canary-token 매칭 확인 |
