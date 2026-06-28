# EERF — 핵심 운영 원칙

## 설계 원칙

1. Platform은 오케스트레이션만. 인프라는 Service Account 소유.
2. Cross-Account IAM은 Org ID 와일드카드. 계정별 ARN 관리 안 함.
3. Failover는 자동, Failback은 수동. CDN 복구 확인 후 운영자가 실행.

## 반드시 기억할 것

| 항목 | 내용 |
|------|------|
| Failover 중 거버넌스 | Approved 서비스는 "삭제됨" 오판 안 함 (필터링됨) |
| Lambda 배포 | `.build/*.zip` 삭제 후 apply (캐시 방지) |
| CDN 원복 후 Failback | CF 전파 5~10분 대기 → 200 확인 후 실행 |
| EventBridge 정시 | `cron(0 * * * ? *)` 사용 (`rate`는 배포 시점 기준) |

## 배포 전 체크

- [ ] Trust Role 존재 확인 (discovery-trust, platform-trust)
- [ ] SNS 이메일 구독 Confirm 완료
- [ ] `.build/*.zip` 삭제
- [ ] `terraform apply -var-file="terraform.tfvars.shared"`
