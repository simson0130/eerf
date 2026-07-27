# Discovery Lambda
data "archive_file" "discovery_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/discovery.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache/**"]
}

resource "aws_lambda_function" "discovery" {
  function_name    = "${var.name_prefix}-discovery"
  role             = aws_iam_role.discovery_lambda.arn
  handler          = "discovery.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.discovery_lambda.output_path
  source_code_hash = data.archive_file.discovery_lambda.output_base64sha256
  timeout          = 900
  memory_size      = 512
  environment {
    variables = {
      NAME_PREFIX    = var.name_prefix
      SNS_TOPIC_ARN  = aws_sns_topic.notify.arn
      AUDIT_BUCKET   = aws_s3_bucket.audit.bucket
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
    }
  }
  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "discovery_schedule" {
  count               = var.enable_scheduled_discovery ? 1 : 0
  name                = "${var.name_prefix}-discovery-schedule"
  schedule_expression = var.discovery_schedule_expression
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "discovery_schedule" {
  count = var.enable_scheduled_discovery ? 1 : 0
  rule  = aws_cloudwatch_event_rule.discovery_schedule[0].name
  arn   = aws_lambda_function.discovery.arn
  input = jsonencode({ accounts = var.discovery_targets })
}

resource "aws_lambda_permission" "discovery_eventbridge" {
  count         = var.enable_scheduled_discovery ? 1 : 0
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discovery.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.discovery_schedule[0].arn
}
