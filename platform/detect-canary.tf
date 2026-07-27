# =============================================================================
# Detect - CloudWatch Synthetics Canary (CDN + Origin 이중경로 헬스체크)
# =============================================================================
# 서비스별 Canary가 CDN과 Origin 양쪽 경로를 동시에 체크
# CDN만 실패하고 Origin 정상이면 FAIL -> Policy Layer가 Failover SFN 트리거
# =============================================================================

# --- Canary S3 Bucket ---

resource "aws_s3_bucket" "canary" {
  bucket_prefix = "${var.name_prefix}-canary-"
  force_destroy = true
  tags          = local.tags
}

# --- Canary Package (syn-python-selenium-11.1) ---

data "archive_file" "canary" {
  type = "zip"
  source {
    content  = file("${path.module}/canary/canary.py")
    filename = "python/canary.py"
  }
  output_path = "${path.module}/.build/canary.zip"
}

resource "aws_s3_object" "canary" {
  bucket       = aws_s3_bucket.canary.id
  key          = "canary/${data.archive_file.canary.output_md5}/canary.zip"
  source       = data.archive_file.canary.output_path
  source_hash  = data.archive_file.canary.output_md5
  content_type = "application/zip"
}

# --- Synthetics Canary (서비스별) ---

resource "aws_synthetics_canary" "path_check" {
  for_each = local.services

  name                 = "${var.name_prefix}-${each.key}"
  artifact_s3_location = "s3://${aws_s3_bucket.canary.bucket}/artifacts/${each.key}/"
  execution_role_arn   = aws_iam_role.canary.arn
  handler              = "canary.handler"
  s3_bucket            = aws_s3_bucket.canary.id
  s3_key               = aws_s3_object.canary.key
  runtime_version      = "syn-python-selenium-11.1"
  start_canary         = true

  vpc_config {
    subnet_ids         = local.canary_subnet_ids
    security_group_ids = [local.canary_security_group_id]
  }

  schedule {
    expression = var.canary_schedule_expression
  }

  run_config {
    timeout_in_seconds = 60
    environment_variables = {
      SERVICE_URL     = "${each.value.canary_cdn_protocol}://${each.value.app_subdomain}.${each.value.domain_name}:${each.value.canary_cdn_port}${each.value.canary_health_path}"
      BACKEND_URL     = "${each.value.canary_origin_protocol}://${each.value.alb_dns_name}:${each.value.canary_origin_port}${each.value.canary_health_path}"
      NAME_PREFIX     = var.name_prefix
      EERF_VERIFY_SSL = tostring(local.verify_ssl)
      CODE_HASH       = data.archive_file.canary.output_md5
    }
  }

  success_retention_period = 7
  failure_retention_period = 14

  tags = merge(local.tags, { Service = each.key })
}

# --- CloudWatch Alarm (서비스별 Canary 실패 감지) ---

resource "aws_cloudwatch_metric_alarm" "canary_failed" {
  for_each = local.services

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

  dimensions = {
    CanaryName = aws_synthetics_canary.path_check[each.key].name
  }

  alarm_actions = [aws_sns_topic.notify.arn]
  ok_actions    = [aws_sns_topic.notify.arn]

  tags = merge(local.tags, { Service = each.key })
}

# --- CloudWatch Alarm (Canary 실행 자체 실패 감지) ---
# Canary Lambda 자체가 실패하면 "Failed" 메트릭이 아닌
# Duration=0 또는 실행 자체가 안 되므로 별도 감지 필요

resource "aws_cloudwatch_metric_alarm" "canary_not_running" {
  for_each = local.services

  alarm_name          = "${var.name_prefix}-${each.key}-canary-not-running"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  metric_name         = "Duration"
  namespace           = "CloudWatchSynthetics"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    CanaryName = aws_synthetics_canary.path_check[each.key].name
  }

  alarm_description = "Canary ${each.key} has not executed for 5 minutes. Possible Lambda failure or configuration issue."
  alarm_actions     = [aws_sns_topic.notify.arn]

  tags = merge(local.tags, { Service = each.key, AlertType = "canary-health" })
}
