# =============================================
# Governance Pipeline
# - Step Functions: Discovery → Diff → Report → Notify
# - EventBridge hourly schedule trigger
# - Diff Engine, Report Generator, Notification Lambda
# =============================================

# =============================================================================
# Lambda Packages (archive_file)
# =============================================================================

data "archive_file" "diff_engine_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/diff_engine.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache", ".pytest_cache/**", "pyyaml-6.0.3.dist-info", "pyyaml-6.0.3.dist-info/**"]
}

data "archive_file" "report_generator_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/report_generator.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache", ".pytest_cache/**", "pyyaml-6.0.3.dist-info", "pyyaml-6.0.3.dist-info/**"]
}

data "archive_file" "notification_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/notification.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache", ".pytest_cache/**", "pyyaml-6.0.3.dist-info", "pyyaml-6.0.3.dist-info/**"]
}

# =============================================================================
# Diff Engine Lambda
# =============================================================================

resource "aws_lambda_function" "diff_engine" {
  function_name    = "${var.name_prefix}-diff-engine"
  role             = aws_iam_role.diff_engine_lambda.arn
  handler          = "diff_engine.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.diff_engine_lambda.output_path
  source_code_hash = data.archive_file.diff_engine_lambda.output_base64sha256
  timeout          = 300
  memory_size      = 512

  environment {
    variables = {
      AUDIT_BUCKET  = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN = aws_sns_topic.notify.arn
    }
  }
  tags = local.tags
}

resource "aws_iam_role" "diff_engine_lambda" {
  name = "${var.name_prefix}-diff-engine-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "diff_engine_lambda" {
  name = "${var.name_prefix}-diff-engine-policy"
  role = aws_iam_role.diff_engine_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.audit.arn}/diffs/*", "${aws_s3_bucket.audit.arn}/approval-state.yaml"]
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Report Generator Lambda
# =============================================================================

resource "aws_lambda_function" "report_generator" {
  function_name    = "${var.name_prefix}-report-generator"
  role             = aws_iam_role.report_generator_lambda.arn
  handler          = "report_generator.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.report_generator_lambda.output_path
  source_code_hash = data.archive_file.report_generator_lambda.output_base64sha256
  timeout          = 120
  memory_size      = 256

  environment {
    variables = {
      AUDIT_BUCKET  = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN = aws_sns_topic.notify.arn
    }
  }
  tags = local.tags
}

resource "aws_iam_role" "report_generator_lambda" {
  name = "${var.name_prefix}-report-generator-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "report_generator_lambda" {
  name = "${var.name_prefix}-report-generator-policy"
  role = aws_iam_role.report_generator_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.audit.arn, "${aws_s3_bucket.audit.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.audit.arn}/reports/*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Notification Lambda
# =============================================================================

resource "aws_lambda_function" "notification" {
  function_name    = "${var.name_prefix}-notification"
  role             = aws_iam_role.notification_lambda.arn
  handler          = "notification.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.notification_lambda.output_path
  source_code_hash = data.archive_file.notification_lambda.output_base64sha256
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      AUDIT_BUCKET      = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN     = aws_sns_topic.notify.arn
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      TZ_OFFSET         = tostring(var.report_timezone_offset)
    }
  }
  tags = local.tags
}

resource "aws_iam_role" "notification_lambda" {
  name = "${var.name_prefix}-notification-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "notification_lambda" {
  name = "${var.name_prefix}-notification-policy"
  role = aws_iam_role.notification_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.audit.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notify.arn
      }
    ]
  })
}

# =============================================================================
# Step Functions Governance Pipeline
# =============================================================================

resource "aws_sfn_state_machine" "governance_pipeline" {
  count = var.enable_governance_pipeline ? 1 : 0
  name     = "${var.name_prefix}-edge-resilience-scan"
  role_arn = aws_iam_role.governance_sfn[0].arn

  definition = jsonencode({
    Comment = "EERF Governance Pipeline: Discovery → Diff → Report → Notify"
    StartAt = "Discovery"
    States = {
      Discovery = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.discovery.arn, "Payload.$" = "$" }
        ResultPath = "$.discovery_result"
        ResultSelector = { "snapshot_key.$" = "$.Payload.snapshot_key", "services_count.$" = "$.Payload.services_count" }
        Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 30, MaxAttempts = 2, BackoffRate = 2.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "ErrorNotify" }]
        Next = "DiffEngine"
      }
      DiffEngine = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.diff_engine.arn, Payload = { "snapshot_key.$" = "$.discovery_result.snapshot_key", "bucket.$" = "$$.Execution.Input.bucket" } }
        ResultPath = "$.diff_result"
        ResultSelector = { "diff_key.$" = "$.Payload.diff_key", "summary.$" = "$.Payload.summary" }
        Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 30, MaxAttempts = 2, BackoffRate = 2.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "ErrorNotify" }]
        Next = "GenerateReport"
      }
      GenerateReport = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.report_generator.arn, Payload = { "diff_key.$" = "$.diff_result.diff_key", "snapshot_key.$" = "$.discovery_result.snapshot_key", "bucket.$" = "$$.Execution.Input.bucket" } }
        ResultPath = "$.report_result"
        ResultSelector = { "report_key.$" = "$.Payload.report_key" }
        Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 30, MaxAttempts = 2, BackoffRate = 2.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "ErrorNotify" }]
        Next = "SendNotification"
      }
      SendNotification = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.notification.arn, Payload = { "report_key.$" = "$.report_result.report_key", "diff_summary.$" = "$.diff_result.summary", "bucket.$" = "$$.Execution.Input.bucket" } }
        ResultPath = "$.notification_result"
        Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 30, MaxAttempts = 2, BackoffRate = 2.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "ErrorNotify" }]
        Next = "Done"
      }
      Done = { Type = "Succeed" }
      ErrorNotify = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.notification.arn, Payload = { "error" = true, "error_message.$" = "$.error.Cause", "error_step.$" = "$.error.Error", "bucket.$" = "$$.Execution.Input.bucket" } }
        ResultPath = "$.error_notify_result"
        Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 30, MaxAttempts = 2, BackoffRate = 2.0 }]
        End = true
      }
    }
  })
  tags = local.tags
}

resource "aws_iam_role" "governance_sfn" {
  count = var.enable_governance_pipeline ? 1 : 0
  name = "${var.name_prefix}-governance-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "states.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "governance_sfn" {
  count = var.enable_governance_pipeline ? 1 : 0
  name = "${var.name_prefix}-governance-sfn-policy"
  role = aws_iam_role.governance_sfn[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [aws_lambda_function.discovery.arn, aws_lambda_function.diff_engine.arn, aws_lambda_function.report_generator.arn, aws_lambda_function.notification.arn] }]
  })
}

# =============================================================================
# EventBridge Governance Pipeline Trigger
# =============================================================================

resource "aws_cloudwatch_event_rule" "governance_pipeline" {
  count               = var.enable_governance_pipeline ? 1 : 0
  name                = "${var.name_prefix}-edge-resilience-scan-trigger"
  schedule_expression = var.governance_schedule_expression
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "governance_pipeline" {
  count    = var.enable_governance_pipeline ? 1 : 0
  rule     = aws_cloudwatch_event_rule.governance_pipeline[0].name
  arn      = aws_sfn_state_machine.governance_pipeline[0].arn
  role_arn = aws_iam_role.eventbridge_governance[0].arn
  input = jsonencode({ org_id = var.org_id, accounts = var.discovery_targets, bucket = aws_s3_bucket.audit.bucket })
}

resource "aws_iam_role" "eventbridge_governance" {
  count = var.enable_governance_pipeline ? 1 : 0
  name = "${var.name_prefix}-eventbridge-governance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "events.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "eventbridge_governance" {
  count = var.enable_governance_pipeline ? 1 : 0
  name = "${var.name_prefix}-eventbridge-governance-policy"
  role = aws_iam_role.eventbridge_governance[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["states:StartExecution"], Resource = aws_sfn_state_machine.governance_pipeline[0].arn }]
  })
}
