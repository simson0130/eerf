# Service Account Dashboard — WAF + ALB + CloudFront
resource "aws_cloudwatch_dashboard" "service" {
  dashboard_name = "${local.full_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # WAF - Allowed vs Blocked vs Counted
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "WAF - Allowed vs Blocked vs Counted"
          region = var.region
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.region, "Rule", "ALL", { stat = "Sum", period = 60, color = "#2ca02c", label = "Allowed" }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.region, "Rule", "ALL", { stat = "Sum", period = 60, color = "#d13212", label = "Blocked" }],
            ["AWS/WAFV2", "CountedRequests", "WebACL", aws_wafv2_web_acl.alb.name, "Region", var.region, "Rule", "ALL", { stat = "Sum", period = 60, color = "#ff7f0e", label = "Counted" }]
          ]
          view    = "timeSeries"
          stacked = false
        }
      },
      # ALB - Requests + Errors
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Requests & Errors"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum", period = 60, label = "Requests" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum", period = 60, color = "#d13212", label = "5xx" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum", period = 60, color = "#ff7f0e", label = "4xx" }]
          ]
          view    = "timeSeries"
          stacked = false
        }
      },
      # CloudFront - Requests + Error Rate
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "CloudFront - Requests & Error Rate"
          region = "us-east-1"
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.cdn.id, "Region", "Global", { stat = "Sum", period = 60, label = "Requests" }],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.cdn.id, "Region", "Global", { stat = "Average", period = 60, color = "#d13212", label = "5xx %", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}
