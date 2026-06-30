# =============================================================================
# ssm-services.tf — 서비스 설정 SSM Parameter Store 등록
# =============================================================================

resource "aws_ssm_parameter" "service_config" {
  for_each = local.services

  name  = "/${var.name_prefix}/services/${each.key}"
  type  = "String"
  value = jsonencode(merge(each.value, {
    service_key = each.key
    app_fqdn    = "${each.value.app_subdomain}.${each.value.domain_name}"
  }))

  tags = local.tags
}

# Phase 4: SNS Topic ARN을 SSM에 저장 (CLI가 조회하여 알림 발송)
resource "aws_ssm_parameter" "sns_topic_arn" {
  name  = "/${var.name_prefix}/config/sns-topic-arn"
  type  = "String"
  value = aws_sns_topic.notify.arn
  tags  = local.tags
}
