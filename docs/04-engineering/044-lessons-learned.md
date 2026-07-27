# EERF Lessons Learned

---

## 2026-07-03: DDB SSOT 전환

### 교훈 1: SSOT를 선언하면 끝까지 일관되게

DDB를 Single Source of Truth로 선언했지만, Report Generator가 여전히 S3 snapshot에 의존하고 있었음.
"SSOT"라고 하면서 일부 컴포넌트만 바꾸면 오히려 더 혼란.

**원칙:** SSOT 전환 시 모든 읽기 경로를 한번에 바꿔야 함. 쓰기만 바꾸고 읽기를 나중에 하면 불일치 발생.

### 교훈 2: 데이터 매칭은 정확한 키로

Report에서 OPER/HEALTH를 가져올 때 `service_key in fqdn` 퍼지 매칭을 쓰면 언젠가 깨짐.
DDB에 service_key가 있으면 그걸 정확히 사용해야 함.

**원칙:** 식별자는 퍼지 매칭 금지. 정확한 키 lookup만 사용.

### 교훈 3: Lambda 배포는 zip 해시에 의존

terraform의 `archive_file`은 `.build/` 폴더에 기존 zip이 있으면 재생성 안 함.
코드를 고치고 `terraform apply`해도 `No changes`가 나올 수 있음.

**원칙:** Lambda 코드 변경 후 배포 시 항상 `Remove-Item .build -Recurse -Force` 먼저.

### 교훈 4: 상태 갱신 책임은 단일 주체

HEALTH를 FO Lambda, FB Lambda, health_update Lambda 3곳에서 갱신하면:
- 경합 발생
- "OK→OK" 상태 변경 안 일어나는 엣지 케이스
- 누가 마지막에 썼는지 모름

**원칙:** 하나의 데이터를 갱신하는 주체는 1개만. `canary-health-sync`만 HEALTH 책임.

### 교훈 5: IAM 권한은 코드 변경과 함께

Report Generator를 DDB 직접 조회로 바꿨는데 IAM에 DynamoDB 권한이 없어서 AccessDenied.
코드가 새 리소스를 접근하면 IAM도 같이 변경해야 함.

**원칙:** 코드에서 새 AWS 서비스 호출 추가 시 → IAM 정책 동시 수정.

### 교훈 6: Report의 카운트 로직은 데이터 소스와 일치해야

`_compute_approval_counts`가 changes 리스트를 순회하면서 매칭하는 방식은 snapshot 기반일 때의 로직.
DDB에서 직접 GOVERNANCE를 읽으면 거기서 바로 카운트하면 됨.

**원칙:** 카운트/집계 로직의 데이터 소스가 바뀌면 로직도 같이 단순화.

---

## 이전 교훈 (Phase 1~4)

- Canary: CDN+Origin 이중 검증 없이는 오탐 발생
- WAF LockToken: 동시 변경 시 재시도 필수
- Failover: 부분 실패 시 롤백 안 하면 불일치 상태
- Cross-Account: Trust Role Principal이 안 맞으면 AccessDenied
- SES: terraform apply 시 환경변수 누락되면 SNS fallback

---

## 2026-07-21: Phase 3~4 (Portal + Production Hardening)

### 교훈 7: Portal UX는 운영 워크플로우를 따라가야

처음엔 기능별(Discovery 페이지, Evaluate 페이지)로 나눴지만, 운영자는 "보호 대상 → 승인 → 리허설 → 감시"의 흐름으로 사고함.
CORF Lifecycle 순서로 메뉴를 재배치한 후 UX 만족도가 크게 개선.

**원칙:** 기능 중심이 아닌 **워크플로우 중심** 메뉴 구조.

### 교훈 8: 정책과 로직을 분리하지 않으면 코드 변경 없이 운영이 불가

처음엔 `failover.py`에 kill-switch, blast radius, governance 검사가 하드코딩.
정책 변경할 때마다 코드 수정 + 배포 필요 → 운영 민첩성 0.
`policy_decision.py` + DDB 분리 후 Portal에서 즉시 규칙 변경 가능.

**원칙:** "복구해야 하는가"(정책)와 "어떻게 복구하는가"(로직)는 별도 모듈. 정책은 데이터로 표현.

### 교훈 9: "terraform apply = 보호 완료"는 거짓

Canary를 생성했지만 실행이 안 되는 경우, SFN이 있지만 EventBridge Rule이 비활성인 경우 등.
`approved → protected` 자동 승격에 5가지 조건(canary active + alarm OK + SFN exist + readiness 100 + optional drill)을 넣은 후에야 "보호됨"의 의미가 정확해짐.

**원칙:** IaC 배포 성공 ≠ 시스템 동작. **검증(Validation)**을 반드시 거쳐야 완료 선언.

### 교훈 10: drill과 실제 인시던트를 분리하지 않으면 KPI가 오염

FO 테스트(drill)와 실제 장애의 MTTR을 구분 없이 섞으면 경영진 보고서의 신뢰도 하락.
`drill_active` 플래그 + `source` 필드 + `correlation_id`로 분리한 후 MTTD/MTTR 게이지를 실제/리허설 탭으로 분리.

**원칙:** 테스트 데이터와 운영 데이터는 **반드시** 분리. 같은 파이프라인을 쓰되 태깅으로 구분.

### 교훈 11: Evidence는 불변이어야 감사 의미가 있음

"MTTR 3분" 증적을 누군가 사후 수정 가능하면 감사에서 "이 수치를 어떻게 믿느냐" 질문 발생.
S3 Object Lock (Governance mode, 365일)을 적용한 후에야 "변조 불가" 선언 가능.

**원칙:** 감사 증적은 **쓰기 전용(append-only) + 불변성(immutable)**이 기본.

### 교훈 12: CORF 평가 체계는 MUST/SHOULD로 나눠야 의미 있음

처음엔 모든 항목에 점수를 매겨 100점 만점으로 평가. 하지만 80점이든 90점이든 "운영 가능한가?"에 대한 답이 안 됨.
MUST(필수): binary pass/fail → 하나라도 FAIL이면 프로덕션 불가.
SHOULD(권고): 성숙도 점수 → 얼마나 잘 하고 있는가.
이렇게 나누니 "Production Ready인가?" 질문에 즉답 가능.

**원칙:** 컴플라이언스 평가는 **필수/권고 이분법**으로. 숫자만으로는 의사결정 불가.

---

## 2026-07-24: Canary 운영 안정화

### 교훈 13: CloudWatch Synthetics 로그 그룹 이름에 UUID가 포함된다

Synthetics Canary를 생성하면 로그 그룹이 `/aws/lambda/cwsyn-{canary_name}-{uuid}` 형태로 자동 생성됨.
이 UUID는 Canary 재생성 시 변경되므로, Dashboard 위젯에서 로그 그룹을 하드코딩하면 Canary 재배포 후 위젯이 깨짐.
Terraform `aws_cloudwatch_log_group`으로 고정 이름을 붙이려 해도 Synthetics가 자체 이름 규칙을 강제함.

**해결:** Dashboard에서 Synthetics 로그 그룹 위젯을 제거하고, CloudWatch Logs Insights로 동적 쿼리하거나 Canary 커스텀 메트릭(`eerf/Canary` namespace)을 시각화하는 방식으로 전환.

**원칙:** AWS 관리형 서비스가 자동 생성하는 리소스(로그 그룹, ENI 등)는 이름이 불변임을 보장할 수 없다. 해당 리소스를 참조할 때는 **이름 직접 참조 대신 API 질의나 태그 기반 검색**을 사용해야 한다.

### 교훈 14: Canary Lambda zip 배포는 S3 key hash로 해결

Terraform `archive_file`로 canary.zip을 생성하면 로컬 `.build/` 디렉토리에 캐시됨.
`canary.py` 코드를 수정해도 기존 zip 파일이 남아있으면 `output_md5`가 변경되지 않아 `terraform apply`가 "No changes"를 반환.
수동으로 `.build/` 삭제 후 apply하는 워크어라운드를 쓰다가, 배포 누락 사고 발생.

**해결:** S3 object key에 `output_md5`를 포함시켜 (`canary/${md5}/canary.zip`) 해시가 바뀌면 새 key로 업로드 → Canary가 새 S3 key를 참조 → 코드 변경 시 항상 재배포.

```hcl
resource "aws_s3_object" "canary" {
  key = "canary/${data.archive_file.canary.output_md5}/canary.zip"
  ...
}
```

**원칙:** Lambda/Canary 코드 배포는 **콘텐츠 해시 기반 key**로 관리해야 한다. 파일 존재 여부가 아닌 내용 변경 여부로 배포를 결정해야 "코드는 바꿨는데 배포가 안 된" 사고를 방지할 수 있다.
