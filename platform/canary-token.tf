# Canary Token — SSM SecureString + 자동 초기값 생성
# rotation Lambda가 주기적으로 갱신하므로 value는 lifecycle ignore

resource "random_password" "canary_token" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "canary_token" {
  name      = "/${var.name_prefix}/canary/token"
  type      = "SecureString"
  value     = random_password.canary_token.result
  overwrite = true

  tags = local.tags

  lifecycle {
    ignore_changes = [value]
  }
}

# -----------------------------
# Token Rotation Lambda
# -----------------------------
data "archive_file" "token_rotation_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/token_rotation.py"
  output_path = "${path.module}/.build/token_rotation.zip"
}

resource "aws_lambda_function" "token_rotation" {
  function_name    = "${var.name_prefix}-token-rotation"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "token_rotation.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.token_rotation_lambda.output_path
  source_code_hash = data.archive_file.token_rotation_lambda.output_base64sha256
  timeout          = 300

  environment {
    variables = {
      AUDIT_BUCKET  = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN = aws_sns_topic.notify.arn
      NAME_PREFIX   = var.name_prefix
    }
  }

  tags = local.tags
}

# -----------------------------
# 90-day rotation schedule (EventBridge)
# -----------------------------
resource "aws_cloudwatch_event_rule" "token_rotation" {
  name                = "${var.name_prefix}-token-rotation"
  description         = "Rotate canary token every 90 days"
  schedule_expression = "rate(90 days)"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "token_rotation" {
  rule = aws_cloudwatch_event_rule.token_rotation.name
  arn  = aws_lambda_function.token_rotation.arn
}

resource "aws_lambda_permission" "token_rotation" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.token_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.token_rotation.arn
}
