# =============================================================================
# Policy Layer — EventBridge: Alarm ALARM → Failover SFN
# =============================================================================

resource "aws_iam_role" "events_to_sfn" {
  name = "${var.name_prefix}-events-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "events.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "events_to_sfn" {
  name = "${var.name_prefix}-events-sfn-policy"
  role = aws_iam_role.events_to_sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "states:StartExecution", Resource = [for sfn in aws_sfn_state_machine.failover : sfn.arn] }]
  })
}

resource "aws_cloudwatch_event_rule" "alarm_to_sfn" {
  for_each = local.services
  name = "${var.name_prefix}-${each.key}-alarm-to-sfn"
  event_pattern = jsonencode({
    source = ["aws.cloudwatch"], "detail-type" = ["CloudWatch Alarm State Change"]
    detail = { alarmName = [aws_cloudwatch_metric_alarm.canary_failed[each.key].alarm_name], state = { value = ["ALARM"] } }
  })
  tags = merge(local.tags, { Service = each.key })
}

resource "aws_cloudwatch_event_target" "alarm_to_sfn" {
  for_each = local.services
  rule     = aws_cloudwatch_event_rule.alarm_to_sfn[each.key].name
  arn      = aws_sfn_state_machine.failover[each.key].arn
  role_arn = aws_iam_role.events_to_sfn.arn
  input_transformer {
    input_paths = { alarmName = "$.detail.alarmName", time = "$.time" }
    input_template = <<EOF
{ "alarmName": <alarmName>, "triggerTime": <time>, "service_key": "${each.key}", "source_type": "alarm", "operator_id": "system (alarm)" }
EOF
  }
}
