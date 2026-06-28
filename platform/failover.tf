# Step Functions - Failover + Manual Failback (per-service)
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
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = concat(
        [for fn in aws_lambda_function.failover : fn.arn],
        [for fn in aws_lambda_function.failback : fn.arn],
        [for fn in aws_lambda_function.dns_validate : fn.arn]
      )
    }]
  })
}

resource "aws_sfn_state_machine" "failover" {
  for_each = var.services
  name     = "${var.name_prefix}-${each.key}-failover"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    Comment = "Auto failover for ${each.key}"
    StartAt = "ExecuteFailover"
    States = {
      ExecuteFailover = {
        Type = "Task", Resource = aws_lambda_function.failover[each.key].arn
        Parameters = { "action" = "failover", "source.$" = "$" }
        ResultPath = "$.switchResult", Next = "WaitForDnsPropagation"
      }
      WaitForDnsPropagation = { Type = "Wait", Seconds = 45, Next = "ValidateDnsAndHealth" }
      ValidateDnsAndHealth = {
        Type = "Task", Resource = aws_lambda_function.dns_validate[each.key].arn
        ResultPath = "$.validationResult"
        Retry = [{ ErrorEquals = ["States.ALL"], IntervalSeconds = 15, MaxAttempts = 8, BackoffRate = 1.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.validationError", Next = "RollbackFailback" }]
        Next = "Success"
      }
      RollbackFailback = { Type = "Task", Resource = aws_lambda_function.failback[each.key].arn, ResultPath = "$.rollbackResult", Next = "FailAfterRollback" }
      Success = { Type = "Succeed" }
      FailAfterRollback = { Type = "Fail", Error = "DnsOrHealthValidationFailed", Cause = "Failover validation failed - auto rollback executed" }
    }
  })
  tags = merge(local.tags, { Service = each.key })
}

resource "aws_sfn_state_machine" "manual_failback" {
  for_each = var.services
  name     = "${var.name_prefix}-${each.key}-manual-failback"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    Comment = "Manual failback for ${each.key}"
    StartAt = "ExecuteFailback"
    States = {
      ExecuteFailback = { Type = "Task", Resource = aws_lambda_function.failback[each.key].arn, ResultPath = "$.failbackResult", Next = "WaitForDnsPropagation" }
      WaitForDnsPropagation = { Type = "Wait", Seconds = 45, Next = "ValidateDnsAndHealth" }
      ValidateDnsAndHealth = {
        Type = "Task", Resource = aws_lambda_function.dns_validate[each.key].arn, ResultPath = "$.validationResult"
        Retry = [{ ErrorEquals = ["States.ALL"], IntervalSeconds = 15, MaxAttempts = 8, BackoffRate = 1.0 }]
        End = true
      }
    }
  })
  tags = merge(local.tags, { Service = each.key })
}
