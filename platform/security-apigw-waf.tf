# API Gateway WAF + Rate Limiting
resource "aws_wafv2_web_acl" "api" {
  name  = "${var.name_prefix}-api-waf"
  scope = "REGIONAL"
  default_action { allow {} }

  rule {
    name = "RateLimit"; priority = 1
    action { block {} }
    statement { rate_based_statement { limit = 1000; aggregate_key_type = "IP" } }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "${var.name_prefix}-api-rate-limit"; sampled_requests_enabled = true }
  }

  rule {
    name = "AWSManagedRulesCommon"; priority = 2
    override_action { count {} }
    statement { managed_rule_group_statement { name = "AWSManagedRulesCommonRuleSet"; vendor_name = "AWS" } }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "${var.name_prefix}-api-common"; sampled_requests_enabled = true }
  }

  rule {
    name = "AWSManagedRulesKnownBadInputs"; priority = 3
    override_action { none {} }
    statement { managed_rule_group_statement { name = "AWSManagedRulesKnownBadInputsRuleSet"; vendor_name = "AWS" } }
    visibility_config { cloudwatch_metrics_enabled = true; metric_name = "${var.name_prefix}-api-bad-inputs"; sampled_requests_enabled = true }
  }

  visibility_config { cloudwatch_metrics_enabled = true; metric_name = "${var.name_prefix}-api-waf"; sampled_requests_enabled = true }
  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}

resource "aws_api_gateway_usage_plan" "portal" {
  name = "${var.name_prefix}-portal-usage-plan"
  api_stages { api_id = aws_api_gateway_rest_api.portal.id; stage = aws_api_gateway_stage.prod.stage_name }
  throttle_settings { burst_limit = 50; rate_limit = 20 }
  tags = local.tags
}
