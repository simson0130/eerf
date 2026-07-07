# EERF Lessons Learned

---

## DDB SSOT 전환 (2026-07)

### 1. SSOT를 선언하면 끝까지 일관되게

DDB를 SSOT로 선언했지만 Report Generator가 여전히 S3 snapshot에 의존.

**원칙:** 모든 읽기 경로를 한번에 바꾸어야 함.

### 2. 식별자는 퍼지 매칭 금지

`service_key in fqdn` 같은 부분 매칭은 언젠가 깨짐.

**원칙:** 정확한 키 lookup만 사용.

### 3. Lambda 배포는 zip 해시에 의존

`.build/` 폴더에 기존 zip이 있으면 재생성 안 함.

**원칙:** 코드 변경 후 항상 `Remove-Item .build\*.zip -Force` 먼저.

### 4. 상태 갱신 책임은 단일 주체

HEALTH를 3곳에서 갱신하면 경합 발생.

**원칙:** 하나의 데이터를 갱신하는 주체는 1개만.

### 5. IAM 권한은 코드 변경과 함께

새 AWS 서비스 호출 추가 시 IAM 정책 동시 수정.

### 6. 카운트 로직은 데이터 소스와 일치

DDB에서 읽으면 DDB에서 바로 카운트.

---

## 이전 교훈 (Phase 1~4)

- Canary: CDN+Origin 이중 검증 없이는 오탐
- WAF LockToken: 동시 변경 시 재시도 필수
- Failover: 부분 실패 시 롤백 필수
- Cross-Account: Trust Role Principal 불일치 → AccessDenied
- SES: 환경변수 누락 시 SNS fallback
