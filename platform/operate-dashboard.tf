# CloudWatch Dashboard (dynamic per-service widgets)
# Note: Canary log group UUIDs are dynamic and may need manual update after Canary recreation

resource "aws_cloudwatch_dashboard" "eerf" {
  count          = var.dashboard_enabled ? 1 : 0
  dashboard_name = "${var.name_prefix}-edge-resilience"

  dashboard_body = jsonencode({
    widgets = concat(
      # Alarm status widget
      [{
        type = "alarm", x = 0, y = 0, width = 24, height = 3
        properties = {
          alarms = [for k, v in aws_cloudwatch_metric_alarm.canary_failed : v.arn]
          title  = "Service Protection Status (Canary Alarms)"
        }
      }],
      # Canary success rate per service
      [{
        type = "metric", x = 0, y = 3, width = 24, height = 6
        properties = {
          metrics = [for k, v in aws_synthetics_canary.path_check : ["CloudWatchSynthetics", "SuccessPercent", "CanaryName", v.name, { label = k, stat = "Average" }]]
          period = 300, region = var.region, stacked = false
          title = "Canary Success Rate (7d)", view = "timeSeries"
          yAxis = { left = { max = 100, min = 0 } }
        }
      }],
      # SFN execution history
      [{
        type = "metric", x = 0, y = 9, width = 12, height = 6
        properties = {
          metrics = [for k, v in aws_sfn_state_machine.failover : ["AWS/States", "ExecutionsStarted", "StateMachineArn", v.arn, { label = k, stat = "Sum" }]]
          period = 3600, region = var.region, stacked = true
          title = "Failover SFN Executions (14d)", view = "timeSeries"
        }
      }],
      # CDN Health custom metrics
      [{
        type = "metric", x = 0, y = 15, width = 12, height = 6
        properties = {
          metrics = [for k, v in local.services : ["${var.name_prefix}/Canary", "CDNHealthy", "Service", "${v.app_subdomain}.${v.domain_name}", { label = k, stat = "Minimum" }]]
          period = 60, region = var.region, stacked = false
          title = "CDN Health (per-service)", view = "timeSeries"
          yAxis = { left = { max = 1, min = 0 } }
        }
      }],
      # Origin Health custom metrics
      [{
        type = "metric", x = 12, y = 15, width = 12, height = 6
        properties = {
          metrics = [for k, v in local.services : ["${var.name_prefix}/Canary", "OriginHealthy", "Service", "${v.app_subdomain}.${v.domain_name}", { label = k, stat = "Minimum" }]]
          period = 60, region = var.region, stacked = false
          title = "Origin Health (per-service)", view = "timeSeries"
          yAxis = { left = { max = 1, min = 0 } }
        }
      }],
    )
  })
}
