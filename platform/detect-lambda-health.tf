# =============================================================================
# Detect - Canary Health Sync Lambda (5min interval)
# =============================================================================

data "archive_file" "canary_health_sync" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/canary_health_sync.zip"
  excludes    = ["tests", "__pycache__", "*.pyc"]
}

resource "aws_lambda_function" "canary_health_sync" {
  function_name    = "${var.name_prefix}-canary-health-sync"
  filename         = data.archive_file.canary_health_sync.output_path
  source_code_hash = data.archive_file.canary_health_sync.output_base64sha256
  handler          = "canary_health_sync.handler"
  runtime          = "python3.13"
  timeout          = 60
  memory_size      = 128
  role             = aws_iam_role.canary_health_sync.arn
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
      NAME_PREFIX    = var.name_prefix
    }
  }
  tags = merge(local.tags, { Purpose = "canary-health-sync" })
}

resource "aws_cloudwatch_event_rule" "canary_health_sync_schedule" {
  name                = "${var.name_prefix}-canary-health-sync"
  schedule_expression = "rate(5 minutes)"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "canary_health_sync" {
  rule = aws_cloudwatch_event_rule.canary_health_sync_schedule.name
  arn  = aws_lambda_function.canary_health_sync.arn
}

resource "aws_lambda_permission" "canary_health_sync_schedule" {
  statement_id  = "AllowEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.canary_health_sync.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.canary_health_sync_schedule.arn
}
