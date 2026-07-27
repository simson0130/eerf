# =============================================================================
# Recover — Failover SFN (per-service auto CDN failover)
# CDN failure -> Route53 switch -> DNS validate -> auto rollback on failure
# =============================================================================

resource "aws_iam_role" "sfn" {
  name = "${var.name_prefix}-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "states.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "sfn" {
  name = "${var.name_prefix}-sfn-policy"
  role = aws_iam_role.sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["lambda:InvokeFunction"]
      Resource = [
        aws_lambda_function.failover.arn,
        aws_lambda_function.failback.arn,
        aws_lambda_function.dns_validate.arn,
        aws_lambda_function.evidence_record.arn,
      ]
    }]
  })
}

resource "aws_sfn_state_machine" "failover" {
  for_each = local.services
  name     = "${var.name_prefix}-${each.key}-failover"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    Comment = "Auto failover for ${each.key}"
    StartAt = "ExecuteFailover"
    TimeoutSeconds = 300
    States = {
      ExecuteFailover = {
        Type = "Task", Resource = aws_lambda_function.failover.arn
        Parameters = { "service_key" = each.key, "source_type.$" = "$.source_type", "operator_id.$" = "$.operator_id", "correlation_id.$" = "$$.Execution.Id" }
        ResultPath = "$.switchResult", Next = "WaitForDnsPropagation"
      }
      WaitForDnsPropagation = { Type = "Wait", Seconds = 45, Next = "ValidateDnsAndHealth" }
      ValidateDnsAndHealth = {
        Type = "Task", Resource = aws_lambda_function.dns_validate.arn
        Parameters = { "service_key" = each.key }
        ResultPath = "$.validationResult"
        Retry = [{ ErrorEquals = ["States.ALL"], IntervalSeconds = 15, MaxAttempts = 8, BackoffRate = 1.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.validationError", Next = "RollbackFailback" }]
        Next = "RecordEvidence"
      }
      RecordEvidence = {
        Type = "Task", Resource = aws_lambda_function.evidence_record.arn
        Parameters = { "service_key" = each.key, "action" = "failover", "execution_arn.$" = "$$.Execution.Id", "trigger_time.$" = "$$.Execution.StartTime", "outcome" = "success", "before_state.$" = "$.switchResult.before_state", "after_state.$" = "$.switchResult.after_state", "affected_resources.$" = "$.switchResult.affected_resources", "correlation_id.$" = "$$.Execution.Id", "mttd_seconds.$" = "$.switchResult.mttd_seconds" }
        ResultPath = "$.evidenceResult"
        Retry = [{ ErrorEquals = ["States.ALL"], IntervalSeconds = 5, MaxAttempts = 2, BackoffRate = 2.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.evidenceError", Next = "Success" }]
        Next = "Success"
      }
      RollbackFailback = {
        Type = "Task", Resource = aws_lambda_function.failback.arn
        Parameters = { "service_key" = each.key }
        ResultPath = "$.rollbackResult", Next = "RecordEvidenceFailed"
      }
      RecordEvidenceFailed = {
        Type = "Task", Resource = aws_lambda_function.evidence_record.arn
        Parameters = { "service_key" = each.key, "action" = "failover", "execution_arn.$" = "$$.Execution.Id", "trigger_time.$" = "$$.Execution.StartTime", "outcome" = "rollback" }
        ResultPath = "$.evidenceResult"
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.evidenceError", Next = "FailAfterRollback" }]
        Next = "FailAfterRollback"
      }
      Success = { Type = "Succeed" }
      FailAfterRollback = { Type = "Fail", Error = "DnsOrHealthValidationFailed", Cause = "Failover validation failed and automatic failback was executed" }
    }
  })
  tags = merge(local.tags, { Service = each.key })
}

# SFN failure alert
resource "aws_cloudwatch_event_rule" "sfn_failure_alert" {
  name = "${var.name_prefix}-sfn-failure-alert"
  event_pattern = jsonencode({
    source = ["aws.states"], "detail-type" = ["Step Functions Execution Status Change"]
    detail = { status = ["FAILED", "TIMED_OUT", "ABORTED"] }
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "sfn_failure_to_sns" {
  rule = aws_cloudwatch_event_rule.sfn_failure_alert.name
  target_id = "${var.name_prefix}-sfn-failure-sns"
  arn = aws_sns_topic.notify.arn
}

resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.notify.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Sid = "AllowEventBridgePublish", Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sns:Publish", Resource = aws_sns_topic.notify.arn }]
  })
}
