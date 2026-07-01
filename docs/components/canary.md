# Canary — Dual-Path Edge Monitoring

> "Edge만 죽었는지" 정확히 판단하는 모니터링 컴포넌트.

---

## 설계 원칙

일반적인 health check는 "Origin이 살았는지"만 확인합니다.
EERF Canary는 "CDN 경로가 살았는지" AND "Origin 경로가 살았는지"를 **동시에** 확인합니다.

---

## 판정 로직

```python
cf_status, cf_ok = check_path(cloudfront_url, token)
origin_status, origin_ok = check_path(origin_url, token)

if not cf_ok and origin_ok:     # Edge-only fault → FAIL (FO 트리거)
if not cf_ok and not origin_ok:  # 전체 장애 → FAIL (알람만)
# cf_ok → PASS (정상)
```

| CDN | Origin | 결과 | 의미 |
|-----|--------|------|------|
| ✓ | ✓/✗ | PASS | 정상 |
| ✗ | ✓ | FAIL | **Edge-only → Failover** |
| ✗ | ✗ | FAIL | 전체 장애 (FO 무의미) |

---

## Canary Token

WAF BLOCK 모드에서도 Canary 요청은 통과해야 합니다.

```
WAF Rule: AllowCanaryHealthCheck (Priority 1)
  └── ByteMatch: header "x-canary-token" == {SSM 토큰값}
  └── Action: ALLOW
```

### Token Rotation (90일)

```
EventBridge(rate 90 days) → Token Rotation Lambda
  1. secrets.token_urlsafe(32) 생성
  2. SSM SecureString 업데이트
  3. 각 Service Account WAF 룰 업데이트
  4. 감사 로그 + SNS 알림
```

---

## 알람 설정

| 항목 | 값 | 이유 |
|------|-----|------|
| Period | 60초 | Canary 주기와 동일 |
| Datapoints | 2/2 | 1회 실패는 무시 |
| Missing data | Not Breaching | 미실행 시 정상 간주 |

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `platform/canary/canary.py` | Canary handler |
| `platform/canary.tf` | Canary + Alarm + EventBridge |
| `platform/canary-token.tf` | Token rotation |
| `platform/lambda/token_rotation.py` | Rotation 구현 |

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| Origin 체크 실패 | ALB redirect | http:// 사용, 301도 정상 |
| Canary 403 | Token mismatch | SSM vs WAF SearchString 비교 |
| Alarm 안 울림 | start_canary=false | true로 변경 |
