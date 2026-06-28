# Lambda Packages + Functions (per-service)
data "archive_file" "failover_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/failover.py"
  output_path = "${path.module}/.build/failover.zip"
}

data "archive_file" "failback_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/failback.py"
  output_path = "${path.module}/.build/failback.zip"
}

data "archive_file" "dns_validate_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/dns_validate.py"
  output_path = "${path.module}/.build/dns_validate.zip"
}

resource "aws_lambda_function" "failover" {
  for_each         = var.services
  function_name    = "${var.name_prefix}-${each.key}-failover"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "failover.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.failover_lambda.output_path
  source_code_hash = data.archive_file.failover_lambda.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      SERVICE_NAME        = each.key
      CROSS_ACCOUNT_ROLE  = each.value.cross_account_role_arn
      HOSTED_ZONE_ID      = each.value.hosted_zone_id
      APP_FQDN            = "${each.value.app_subdomain}.${each.value.domain_name}"
      CLOUDFRONT_DNS_NAME = each.value.cloudfront_dns_name
      CLOUDFRONT_ZONE_ID  = each.value.cloudfront_zone_id
      ALB_DNS_NAME        = each.value.alb_dns_name
      ALB_ZONE_ID         = each.value.alb_zone_id
      ALB_ARN             = each.value.alb_arn
      EMERGENCY_SG_ID     = each.value.emergency_sg_id
      WEB_ACL_NAME        = each.value.web_acl_name
      WEB_ACL_ID          = each.value.web_acl_id
      WEB_ACL_SCOPE       = "REGIONAL"
      AUDIT_BUCKET        = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN       = aws_sns_topic.notify.arn
    }
  }
  tags = merge(local.tags, { Service = each.key })
}

resource "aws_lambda_function" "failback" {
  for_each         = var.services
  function_name    = "${var.name_prefix}-${each.key}-failback"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "failback.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.failback_lambda.output_path
  source_code_hash = data.archive_file.failback_lambda.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      SERVICE_NAME        = each.key
      CROSS_ACCOUNT_ROLE  = each.value.cross_account_role_arn
      HOSTED_ZONE_ID      = each.value.hosted_zone_id
      APP_FQDN            = "${each.value.app_subdomain}.${each.value.domain_name}"
      CLOUDFRONT_DNS_NAME = each.value.cloudfront_dns_name
      CLOUDFRONT_ZONE_ID  = each.value.cloudfront_zone_id
      ALB_ARN             = each.value.alb_arn
      EMERGENCY_SG_ID     = each.value.emergency_sg_id
      WEB_ACL_NAME        = each.value.web_acl_name
      WEB_ACL_ID          = each.value.web_acl_id
      WEB_ACL_SCOPE       = "REGIONAL"
      AUDIT_BUCKET        = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN       = aws_sns_topic.notify.arn
    }
  }
  tags = merge(local.tags, { Service = each.key })
}

resource "aws_lambda_function" "dns_validate" {
  for_each         = var.services
  function_name    = "${var.name_prefix}-${each.key}-dns-validate"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "dns_validate.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.dns_validate_lambda.output_path
  source_code_hash = data.archive_file.dns_validate_lambda.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      SERVICE_NAME       = each.key
      CROSS_ACCOUNT_ROLE = each.value.cross_account_role_arn
      APP_FQDN           = "${each.value.app_subdomain}.${each.value.domain_name}"
      HOSTED_ZONE_ID     = each.value.hosted_zone_id
    }
  }
  tags = merge(local.tags, { Service = each.key })
}
