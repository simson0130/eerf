# Governance SFN Pipeline (Discovery → Evaluate → Report → Notify)
resource "aws_sfn_state_machine" "governance_pipeline" {
  count    = var.enable_governance_pipeline ? 1 : 0
  name     = "${var.name_prefix}-edge-resilience-scan"
  role_arn = aws_iam_role.governance_sfn[0].arn
  definition = jsonencode({
    Comment = "EERF Governance Pipeline"
    StartAt = "Discovery"
    States = {
      Discovery = { Type = "Task", Resource = "arn:aws:states:::lambda:invoke", Parameters = { FunctionName = aws_lambda_function.discovery.arn, "Payload.$" = "$" }, ResultPath = "$.discovery_result", Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "Done" }], Next = "Evaluate" }
      Evaluate = { Type = "Task", Resource = "arn:aws:states:::lambda:invoke", Parameters = { FunctionName = aws_lambda_function.evaluate.arn, Payload = {} }, ResultPath = "$.evaluate_result", Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.evaluate_error", Next = "GenerateReport" }], Next = "GenerateReport" }
      GenerateReport = { Type = "Task", Resource = "arn:aws:states:::lambda:invoke", Parameters = { FunctionName = aws_lambda_function.report_generator.arn, Payload = { "bucket.$" = "$$.Execution.Input.bucket" } }, ResultPath = "$.report_result", Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "Done" }], Next = "Done" }
      Done = { Type = "Succeed" }
    }
  })
  tags = local.tags
}

resource "aws_iam_role" "governance_sfn" {
  count = var.enable_governance_pipeline ? 1 : 0
  name  = "${var.name_prefix}-governance-sfn-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "states.amazonaws.com" } }] })
  tags = local.tags
}

resource "aws_iam_role_policy" "governance_sfn" {
  count = var.enable_governance_pipeline ? 1 : 0
  name  = "${var.name_prefix}-governance-sfn-policy"
  role  = aws_iam_role.governance_sfn[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [aws_lambda_function.discovery.arn, aws_lambda_function.evaluate.arn, aws_lambda_function.report_generator.arn, aws_lambda_function.notification.arn] }] })
}

resource "aws_cloudwatch_event_rule" "governance_pipeline" {
  count               = var.enable_governance_pipeline ? 1 : 0
  name                = "${var.name_prefix}-governance-trigger"
  schedule_expression = var.governance_schedule_expression
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "governance_pipeline" {
  count    = var.enable_governance_pipeline ? 1 : 0
  rule     = aws_cloudwatch_event_rule.governance_pipeline[0].name
  arn      = aws_sfn_state_machine.governance_pipeline[0].arn
  role_arn = aws_iam_role.eventbridge_governance[0].arn
  input    = jsonencode({ org_id = var.org_id, accounts = var.discovery_targets, bucket = aws_s3_bucket.audit.bucket })
}

resource "aws_iam_role" "eventbridge_governance" {
  count = var.enable_governance_pipeline ? 1 : 0
  name  = "${var.name_prefix}-eventbridge-governance-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "events.amazonaws.com" } }] })
  tags = local.tags
}

resource "aws_iam_role_policy" "eventbridge_governance" {
  count = var.enable_governance_pipeline ? 1 : 0
  name  = "${var.name_prefix}-eventbridge-governance-policy"
  role  = aws_iam_role.eventbridge_governance[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["states:StartExecution"], Resource = aws_sfn_state_machine.governance_pipeline[0].arn }] })
}
