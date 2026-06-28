# Canary S3 Bucket
resource "aws_s3_bucket" "canary" {
  bucket_prefix = "${var.name_prefix}-canary-"
  force_destroy = true
  tags          = local.tags
}

# Canary Package
data "archive_file" "canary" {
  type = "zip"
  source {
    content  = file("${path.module}/canary/canary.js")
    filename = "nodejs/node_modules/canary.js"
  }
  output_path = "${path.module}/.build/canary.zip"
}

resource "aws_s3_object" "canary" {
  bucket = aws_s3_bucket.canary.id
  key    = "canary/canary.zip"
  source = data.archive_file.canary.output_path
  etag   = data.archive_file.canary.output_md5
}

# Canary IAM Role
resource "aws_iam_role" "canary" {
  name = "${var.name_prefix}-canary-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "canary" {
  name = "${var.name_prefix}-canary-policy"
  role = aws_iam_role.canary.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetBucketLocation", "s3:ListAllMyBuckets"], Resource = [aws_s3_bucket.canary.arn, "${aws_s3_bucket.canary.arn}/*"] },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["cloudwatch:PutMetricData"], Resource = "*", Condition = { StringEquals = { "cloudwatch:namespace" = "CloudWatchSynthetics" } } }
    ]
  })
}

# Synthetics Canary (per-service)
resource "aws_synthetics_canary" "path_check" {
  for_each             = var.services
  name                 = "${var.name_prefix}-${each.key}"
  artifact_s3_location = "s3://${aws_s3_bucket.canary.bucket}/artifacts/${each.key}/"
  execution_role_arn   = aws_iam_role.canary.arn
  handler              = "canary.handler"
  zip_file             = data.archive_file.canary.output_path
  runtime_version      = "syn-nodejs-puppeteer-16.1"
  start_canary         = true
  schedule { expression = var.canary_schedule_expression }
  run_config {
    timeout_in_seconds = 60
    environment_variables = {
      CLOUDFRONT_URL = "https://${each.value.app_subdomain}.${each.value.domain_name}/health"
      ORIGIN_URL     = "http://${each.value.alb_dns_name}/health"
    }
  }
  success_retention_period = 7
  failure_retention_period = 14
  tags = merge(local.tags, { Service = each.key })
}

# CloudWatch Alarm (per-service)
resource "aws_cloudwatch_metric_alarm" "canary_failed" {
  for_each            = var.services
  alarm_name          = "${var.name_prefix}-${each.key}-cdn-path-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "Failed"
  namespace           = "CloudWatchSynthetics"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions          = { CanaryName = aws_synthetics_canary.path_check[each.key].name }
  alarm_actions       = [aws_sns_topic.notify.arn]
  ok_actions          = [aws_sns_topic.notify.arn]
  tags = merge(local.tags, { Service = each.key })
}

# EventBridge → Step Functions (per-service)
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
  for_each = var.services
  name = "${var.name_prefix}-${each.key}-alarm-to-sfn"
  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = { alarmName = [aws_cloudwatch_metric_alarm.canary_failed[each.key].alarm_name], state = { value = ["ALARM"] } }
  })
  tags = merge(local.tags, { Service = each.key })
}

resource "aws_cloudwatch_event_target" "alarm_to_sfn" {
  for_each = var.services
  rule     = aws_cloudwatch_event_rule.alarm_to_sfn[each.key].name
  arn      = aws_sfn_state_machine.failover[each.key].arn
  role_arn = aws_iam_role.events_to_sfn.arn
  input_transformer {
    input_paths    = { alarmName = "$.detail.alarmName", time = "$.time" }
    input_template = "{\"alarmName\": <alarmName>, \"triggerTime\": <time>, \"action\": \"failover\", \"service\": \"${each.key}\"}"
  }
}
