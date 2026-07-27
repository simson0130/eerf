# =============================================================================
# Recover - Failover / Failback / DNS Validate Lambda
# Shared lambda/ directory packaged as single zip
# =============================================================================

data "archive_file" "platform_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  excludes    = ["tests/**", "__pycache__/**", "*.pyc", ".pytest_cache/**"]
  output_path = "${path.module}/.build/platform_lambda.zip"
}

# Global Kill-Switch SSM
resource "aws_ssm_parameter" "fo_kill_switch" {
  name  = "/${var.name_prefix}/global/fo-enabled"
  type  = "String"
  value = "true"
  lifecycle { ignore_changes = [value] }
  tags = local.tags
}

resource "aws_lambda_function" "failover" {
  function_name    = "${var.name_prefix}-failover"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "failover.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.platform_lambda.output_path
  source_code_hash = data.archive_file.platform_lambda.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      AUDIT_BUCKET            = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN           = aws_sns_topic.notify.arn
      NAME_PREFIX             = var.name_prefix
      DYNAMODB_TABLE          = aws_dynamodb_table.services.name
      MAX_CONCURRENT_FAILOVER = tostring(var.max_concurrent_failover)
    }
  }
  tags = local.tags
}

resource "aws_lambda_function" "failback" {
  function_name    = "${var.name_prefix}-failback"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "failback.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.platform_lambda.output_path
  source_code_hash = data.archive_file.platform_lambda.output_base64sha256
  timeout          = 60
  environment {
    variables = {
      AUDIT_BUCKET   = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN  = aws_sns_topic.notify.arn
      NAME_PREFIX    = var.name_prefix
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
    }
  }
  tags = local.tags
}

resource "aws_lambda_function" "dns_validate" {
  function_name    = "${var.name_prefix}-dns-validate"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "dns_validate.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.platform_lambda.output_path
  source_code_hash = data.archive_file.platform_lambda.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      AUDIT_BUCKET    = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN   = aws_sns_topic.notify.arn
      NAME_PREFIX     = var.name_prefix
      DYNAMODB_TABLE  = aws_dynamodb_table.services.name
      EERF_VERIFY_SSL = tostring(local.verify_ssl)
    }
  }
  tags = local.tags
}
