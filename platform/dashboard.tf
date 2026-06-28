# Platform Dashboard — Canary + Alarm + Step Functions only
# WAF/ALB/CloudFront metrics are in Service Account dashboard
resource "aws_cloudwatch_dashboard" "eerf" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = flatten([
      for svc_key, svc in var.services : [
        {
          type   = "metric"
          x      = 0
          y      = index(keys(var.services), svc_key) * 6
          width  = 8
          height = 6
          properties = {
            title  = "${svc_key} - Canary Success Rate"
            region = var.region
            metrics = [
              ["CloudWatchSynthetics", "SuccessPercent", "CanaryName", aws_synthetics_canary.path_check[svc_key].name, { stat = "Average", period = 60 }]
            ]
            view    = "timeSeries"
            stacked = false
            yAxis   = { left = { min = 0, max = 100 } }
          }
        },
        {
          type   = "alarm"
          x      = 8
          y      = index(keys(var.services), svc_key) * 6
          width  = 8
          height = 6
          properties = {
            title  = "${svc_key} - Alarm"
            alarms = [aws_cloudwatch_metric_alarm.canary_failed[svc_key].arn]
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = index(keys(var.services), svc_key) * 6
          width  = 8
          height = 6
          properties = {
            title  = "${svc_key} - Failover SFN"
            region = var.region
            metrics = [
              ["AWS/States", "ExecutionsStarted", "StateMachineArn", aws_sfn_state_machine.failover[svc_key].arn, { stat = "Sum", period = 300, color = "#1f77b4", label = "Started" }],
              ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.failover[svc_key].arn, { stat = "Sum", period = 300, color = "#2ca02c", label = "Succeeded" }],
              ["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.failover[svc_key].arn, { stat = "Sum", period = 300, color = "#d13212", label = "Failed" }]
            ]
            view    = "timeSeries"
            stacked = false
          }
        }
      ]
    ])
  })
}

# Governance Dashboard
resource "aws_cloudwatch_dashboard" "governance" {
  count = var.enable_governance_pipeline ? 1 : 0
  dashboard_name = "${var.name_prefix}-edge-resilience-center"
  dashboard_body = jsonencode({
    widgets = [
      { type = "text", x = 0, y = 0, width = 24, height = 1, properties = { markdown = "## \ud83d\udcca \uc11c\ube44\uc2a4 \uad00\ub9ac \ud604\ud669" } },
      { type = "metric", x = 0, y = 1, width = 3, height = 4, properties = { title = "\uc804\uccb4 \ubc1c\uacac", region = var.region, metrics = [["EERF/Governance", "TotalDiscovered", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300 } },
      { type = "metric", x = 3, y = 1, width = 3, height = 4, properties = { title = "\uad00\ub9ac \uc911", region = var.region, metrics = [["EERF/Governance", "ActiveProtected", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300 } },
      { type = "metric", x = 6, y = 1, width = 3, height = 4, properties = { title = "\ubbf8\uad00\ub9ac", region = var.region, metrics = [["EERF/Governance", "PendingApproval", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300 } },
      { type = "metric", x = 9, y = 1, width = 3, height = 4, properties = { title = "\uc81c\uc678", region = var.region, metrics = [["EERF/Governance", "Excluded", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300 } },
      { type = "metric", x = 12, y = 1, width = 3, height = 4, properties = { title = "\uad6c\uc131 \ubbf8\uc644", region = var.region, metrics = [["EERF/Governance", "ReviewRequired", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300, color = "#ff7f0e" } },
      { type = "metric", x = 15, y = 1, width = 3, height = 4, properties = { title = "Failover \uc911", region = var.region, metrics = [["EERF/Governance", "FailoverActive", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300, color = "#d62728" } },
      { type = "metric", x = 18, y = 1, width = 3, height = 4, properties = { title = "\uc2a4\uce94 \uc624\ub958", region = var.region, metrics = [["EERF/Governance", "ErrorCount", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300, color = "#d13212" } },
      { type = "metric", x = 21, y = 1, width = 3, height = 4, properties = { title = "\ubcf4\ud638 \ucee4\ubc84\ub9ac\uc9c0", region = var.region, metrics = [["EERF/Governance", "CanaryCoverage", { stat = "Maximum", period = 300 }]], view = "singleValue", stat = "Maximum", period = 300 } },
      { type = "text", x = 0, y = 5, width = 24, height = 1, properties = { markdown = "## \ud83d\udcc8 \uc11c\ube44\uc2a4 \ud604\ud669 \uc774\ub825" } },
      { type = "metric", x = 0, y = 6, width = 12, height = 6, properties = { title = "\uc11c\ube44\uc2a4 \uc778\ubca4\ud1a0\ub9ac \ucd94\uc774 (14\uc77c)", region = var.region, metrics = [["EERF/Governance", "TotalDiscovered", { stat = "Maximum", period = 86400, label = "\uc804\uccb4", color = "#1f77b4" }], ["EERF/Governance", "ActiveProtected", { stat = "Maximum", period = 86400, label = "\uad00\ub9ac", color = "#2ca02c" }], ["EERF/Governance", "PendingApproval", { stat = "Maximum", period = 86400, label = "\ubbf8\uad00\ub9ac", color = "#ff7f0e" }], ["EERF/Governance", "Excluded", { stat = "Maximum", period = 86400, label = "\uc81c\uc678", color = "#9467bd" }]], view = "timeSeries", stacked = false, period = 86400, yAxis = { left = { min = 0 } } } },
      { type = "metric", x = 12, y = 6, width = 12, height = 6, properties = { title = "\uac70\ubc84\ub10c\uc2a4 \uc2a4\uce94 \uc2e4\ud589", region = var.region, metrics = [["AWS/States", "ExecutionsStarted", "StateMachineArn", aws_sfn_state_machine.governance_pipeline[0].arn, { stat = "Sum", period = 86400, color = "#1f77b4", label = "\uc2dc\uc791" }], ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.governance_pipeline[0].arn, { stat = "Sum", period = 86400, color = "#2ca02c", label = "\uc131\uacf5" }], ["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.governance_pipeline[0].arn, { stat = "Sum", period = 86400, color = "#d13212", label = "\uc2e4\ud328" }]], view = "timeSeries", stacked = false, period = 86400 } },
      { type = "text", x = 0, y = 12, width = 24, height = 1, properties = { markdown = "## \ud83d\udd04 Failover / Failback \uc774\ub825" } },
      { type = "text", x = 0, y = 19, width = 24, height = 1, properties = { markdown = "## \ud83d\udccb \uc11c\ube44\uc2a4 \uc0c1\ud0dc (\ucd5c\uadfc \uc2a4\uce94)" } },
      { type = "log", x = 0, y = 20, width = 24, height = 6, properties = { title = "\uc11c\ube44\uc2a4 \uc0c1\ud0dc", region = var.region, query = "SOURCE '/aws/lambda/${var.name_prefix}-report-generator' | filter event_type = 'service_status' | fields service_fqdn, account_id, edge_provider, web_acl_name, approval_status, canary_health, category, last_change_ts | sort @timestamp desc | dedup service_fqdn", view = "table" } },
      { type = "text", x = 0, y = 26, width = 24, height = 1, properties = { markdown = "## \ud83d\udd0d \uc2a4\uce94 \uc624\ub958 \uc0c1\uc138" } },
      { type = "log", x = 0, y = 27, width = 24, height = 5, properties = { title = "Discovery \uc624\ub958 \ub85c\uadf8", region = var.region, query = "SOURCE '/aws/lambda/${var.name_prefix}-discovery' | filter @message like /ERROR/ or @message like /AccessDenied/ | fields @timestamp, @message | sort @timestamp desc | limit 20", view = "table" } }
    ]
  })
}
