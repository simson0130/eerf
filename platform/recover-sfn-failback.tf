# =============================================================================
# Recover — Manual Failback SFN (per-service manual restore)
# =============================================================================

resource "aws_sfn_state_machine" "manual_failback" {
  for_each = local.services
  name     = "${var.name_prefix}-${each.key}-manual-failback"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    Comment = "Manual failback for ${each.key}"
    StartAt = "ExecuteFailback"
    TimeoutSeconds = 300
    States = {
      ExecuteFailback = {
        Type = "Task", Resource = aws_lambda_function.failback.arn
        Parameters = { "service_key" = each.key, "operator_id.$" = "$.operator_id", "reason.$" = "$.reason", "source_type.$" = "$.source_type" }
        ResultPath = "$.failbackResult"
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.failbackError", Next = "RecordEvidenceFailed" }]
        Next = "CheckSkipped"
      }
      CheckSkipped = { Type = "Choice", Choices = [{ Variable = "$.failbackResult.skipped", IsPresent = true, Next = "Done" }], Default = "WaitForDnsPropagation" }
      WaitForDnsPropagation = { Type = "Wait", Seconds = 45, Next = "ValidateDnsAndHealth" }
      ValidateDnsAndHealth = {
        Type = "Task", Resource = aws_lambda_function.dns_validate.arn
        Parameters = { "service_key" = each.key }
        ResultPath = "$.validationResult"
        Retry = [{ ErrorEquals = ["States.ALL"], IntervalSeconds = 15, MaxAttempts = 8, BackoffRate = 1.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.validationError", Next = "RecordEvidenceFailed" }]
        Next = "RecordEvidence"
      }
      RecordEvidence = {
        Type = "Task", Resource = aws_lambda_function.evidence_record.arn
        Parameters = { "service_key" = each.key, "action" = "failback", "execution_arn.$" = "$$.Execution.Id", "trigger_time.$" = "$$.Execution.StartTime", "outcome" = "success", "before_state.$" = "$.failbackResult.before_state", "after_state.$" = "$.failbackResult.after_state", "correlation_id.$" = "$.failbackResult.correlation_id" }
        ResultPath = "$.evidenceResult"
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.evidenceError", Next = "Done" }]
        Next = "Done"
      }
      RecordEvidenceFailed = {
        Type = "Task", Resource = aws_lambda_function.evidence_record.arn
        Parameters = { "service_key" = each.key, "action" = "failback", "execution_arn.$" = "$$.Execution.Id", "outcome" = "failed" }
        ResultPath = "$.evidenceResult"
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.evidenceError", Next = "Done" }]
        Next = "Done"
      }
      Done = { Type = "Succeed" }
    }
  })
  tags = merge(local.tags, { Service = each.key })
}
