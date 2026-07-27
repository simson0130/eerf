# Token Rotation Lambda (90-day cycle)
resource "random_password" "canary_token" { length = 32; special = false }

resource "aws_ssm_parameter" "canary_token" {
  name = "/${var.name_prefix}/canary/token"
  type = "SecureString"
  value = random_password.canary_token.result
  overwrite = true
  lifecycle { ignore_changes = [value] }
  tags = local.tags
}

data "archive_file" "token_rotation_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/token_rotation.py"
  output_path = "${path.module}/.build/token_rotation.zip"
}

resource "aws_lambda_function" "token_rotation" {
  function_name    = "${var.name_prefix}-token-rotation"
  role             = aws_iam_role.token_rotation_lambda.arn
  handler          = "token_rotation.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.token_rotation_lambda.output_path
  source_code_hash = data.archive_file.token_rotation_lambda.output_base64sha256
  timeout          = 300
  environment { variables = { AUDIT_BUCKET = aws_s3_bucket.audit.bucket; SNS_TOPIC_ARN = aws_sns_topic.notify.arn; NAME_PREFIX = var.name_prefix } }
  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "token_rotation" {
  name = "${var.name_prefix}-token-rotation"; schedule_expression = "rate(90 days)"; tags = local.tags
}
resource "aws_cloudwatch_event_target" "token_rotation" { rule = aws_cloudwatch_event_rule.token_rotation.name; arn = aws_lambda_function.token_rotation.arn }
resource "aws_lambda_permission" "token_rotation" {
  statement_id = "AllowEventBridge"; action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.token_rotation.function_name
  principal = "events.amazonaws.com"; source_arn = aws_cloudwatch_event_rule.token_rotation.arn
}
