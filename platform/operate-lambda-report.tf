# Report Generator + Enterprise Report + Notification Lambda
data "archive_file" "report_generator_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/report_generator.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache/**"]
}

data "archive_file" "notification_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/notification.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache/**"]
}

resource "aws_lambda_function" "report_generator" {
  function_name    = "${var.name_prefix}-report-generator"
  role             = aws_iam_role.report_generator_lambda.arn
  handler          = "report_generator.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.report_generator_lambda.output_path
  source_code_hash = data.archive_file.report_generator_lambda.output_base64sha256
  timeout          = 120
  memory_size      = 256
  environment {
    variables = {
      AUDIT_BUCKET   = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN  = aws_sns_topic.notify.arn
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
      HISTORY_TABLE  = aws_dynamodb_table.history.name
      NAME_PREFIX    = var.name_prefix
    }
  }
  tags = local.tags
}

resource "aws_lambda_function" "report_enterprise" {
  count            = var.enable_enterprise_report ? 1 : 0
  function_name    = "${var.name_prefix}-report-enterprise"
  role             = aws_iam_role.report_generator_lambda.arn
  handler          = "report_enterprise.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.report_generator_lambda.output_path
  source_code_hash = data.archive_file.report_generator_lambda.output_base64sha256
  timeout          = 120
  memory_size      = 256
  environment {
    variables = {
      AUDIT_BUCKET   = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN  = aws_sns_topic.notify.arn
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
      HISTORY_TABLE  = aws_dynamodb_table.history.name
      NAME_PREFIX    = var.name_prefix
    }
  }
  tags = local.tags
}

resource "aws_lambda_function" "notification" {
  function_name    = "${var.name_prefix}-notification"
  role             = aws_iam_role.notification_lambda.arn
  handler          = "notification.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.notification_lambda.output_path
  source_code_hash = data.archive_file.notification_lambda.output_base64sha256
  timeout          = 60
  memory_size      = 128
  environment {
    variables = merge(
      { AUDIT_BUCKET = aws_s3_bucket.audit.bucket, SNS_TOPIC_ARN = aws_sns_topic.notify.arn, SLACK_WEBHOOK_URL = var.slack_webhook_url, TZ_OFFSET = tostring(var.report_timezone_offset) },
      var.ses_from_email != "" ? { SES_FROM_EMAIL = var.ses_from_email, SES_TO_EMAILS = var.ses_to_emails } : {}
    )
  }
  tags = local.tags
}
