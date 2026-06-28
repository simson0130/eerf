# EERF Implementation Guide — V2 Multi-Account

---

## Deployment Flow

### Phase 1: Service Account — Trust Role 추가
```bash
cd service/
terraform apply \
  -target=aws_iam_role.discovery_trust \
  -target=aws_iam_role.platform_trust
```

### Phase 2: Platform — Discovery 배포
```bash
cd platform/
terraform apply -target=aws_lambda_function.discovery ...
```

### Phase 3: Discovery 실행
```powershell
aws lambda invoke --function-name eerf-discovery --payload fileb://input.json result.json
```

### Phase 4: 온보딩 (services map)
```hcl
services = {
  "app1" = {
    account_id             = "111111111111"
    domain_name            = "example.com"
    app_subdomain          = "app"
    hosted_zone_id         = "Z0123456789"
    ...
    cross_account_role_arn = "arn:aws:iam::111111111111:role/eerf-app1-platform-trust"
  }
}
```

### Phase 5: 전체 Platform 배포
```bash
terraform apply
```

---

## Lambda Code

| Lambda | 역할 |
|--------|------|
| discovery.py | Cross-Account 서비스 발견 |
| failover.py | DNS+WAF+SG 전환 |
| failback.py | 복원 |
| dns_validate.py | DNS+Health 검증 |
| report_generator.py | Markdown 보고서 |
| notification.py | SNS/Slack 알림 |
| diff_engine.py | 변경 비교 |
| metrics.py | CloudWatch 메트릭 |

---

## Troubleshooting

| 증상 | 해결 |
|------|------|
| AssumeRole 실패 | Trust Role Principal 확인 |
| Discovery 0건 | Route53 Edge CNAME 패턴 확인 |
| Canary FAILED | WAF AllowCanaryHealthCheck 룰 확인 |
| WAF Update 실패 | LockToken 재시도 (SFN Retry) |
