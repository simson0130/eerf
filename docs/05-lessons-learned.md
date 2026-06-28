# EERF — 핵심 운영 원칙

## 설계 원칙

1. Platform은 오케스트레이션만. 인프라는 Service Account 소유.
2. Cross-Account IAM은 Org ID 와일드카드.
3. Failover는 자동, Failback은 수동.

## 용어 정의

| 대시보드/보고서 | 코드 내부값 | 의미 |
|---|---|---|
| 보호 중 | Approved | Canary + Failover 배포 완료 |
| 보호 대기 | Pending_Approval | 준비 완료, 운영자 승인 대기 |
| 구성 미완 | not_ready | ALB/WAF 미연결, 보호 불가 |
| 제외 | Excluded | 의도적 미보호 |
| 장애 전환 중 | Failover | 현재 ALB 직결 상태 |

## 배포 체크리스트

- [ ] Trust Role 존재 확인 (eerf-discovery-trust)
- [ ] SNS 이메일 구독 Confirm
- [ ] .build/*.zip 삭제
- [ ] terraform apply
- [ ] SSM Parameter: /eerf/canary/token
