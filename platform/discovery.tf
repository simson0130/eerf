# Service Discovery Lambda + Schedule
data "archive_file" "discovery_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/discovery.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache", ".pytest_cache/**", "pyyaml-6.0.3.dist-info", "pyyaml-6.0.3.dist-info/**"]
}

resource "aws_lambda_function" "discovery" {
  function_name    = "${var.name_prefix}-discovery"
  role             = aws_iam_role.discovery_lambda.arn
  handler          = "discovery.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.discovery_lambda.output_path
  source_code_hash = data.archive_file.discovery_lambda.output_base64sha256
  timeout          = 900
  memory_size      = 512
  environment {
    variables = {
      NAME_PREFIX   = var.name_prefix
      SNS_TOPIC_ARN = aws_sns_topic.notify.arn
      AUDIT_BUCKET  = aws_s3_bucket.audit.bucket
    }
  }
  tags = local.tags
}

resource "aws_iam_role" "discovery_lambda" {
  name = "${var.name_prefix}-discovery-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "discovery_lambda" {
  name = "${var.name_prefix}-discovery-policy"
  role = aws_iam_role.discovery_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["ssm:PutParameter", "ssm:GetParameter", "ssm:GetParametersByPath"], Resource = "arn:aws:ssm:${var.region}:*:parameter/${var.name_prefix}/discovery/*" },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.audit.arn}/*" },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.notify.arn },
      { Effect = "Allow", Action = "sts:AssumeRole", Resource = var.org_id != "" ? ["arn:aws:iam::*:role/eerf-discovery-trust"] : var.discovery_target_role_arns },
      { Effect = "Allow", Action = ["organizations:ListAccounts"], Resource = "*" },
      { Effect = "Allow", Action = ["cloudwatch:PutMetricData"], Resource = "*" }
    ]
  })
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
