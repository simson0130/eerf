variable "region" {
  description = "Primary AWS region for Platform Account"
  type        = string
  default     = "ap-northeast-2"
}

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
  default     = "eerf"
}

variable "notification_email" {
  description = "Optional email subscription for SNS notification"
  type        = string
  default     = ""
}

# -----------------------------
# Service Account 정보 (멀티 서비스 지원)
# -----------------------------
variable "services" {
  description = "Map of services to protect. Each service defines its account and resource info."
  type = map(object({
    account_id          = string
    domain_name         = string
    app_subdomain       = string
    hosted_zone_id      = string
    alb_arn             = string
    alb_dns_name        = string
    alb_zone_id         = string
    alb_arn_suffix      = string
    cloudfront_dns_name = string
    cloudfront_zone_id  = string
    cloudfront_id       = string
    web_acl_arn         = string
    web_acl_name        = string
    web_acl_id          = string
    emergency_sg_id     = string
    cross_account_role_arn = string
    canary_health_path     = optional(string, "/health")
    canary_cdn_port        = optional(number, 443)
    canary_cdn_protocol    = optional(string, "https")
    canary_origin_port     = optional(number, 80)
    canary_origin_protocol = optional(string, "http")
  }))
  default = {}
}

variable "canary_schedule_expression" {
  description = "CloudWatch Synthetics canary schedule"
  type        = string
  default     = "rate(1 minute)"
}

variable "failover_wait_seconds" {
  description = "DNS propagation wait time (seconds)"
  type        = number
  default     = 45
}

variable "validate_max_attempts" {
  description = "DNS+HTTP validation retry count"
  type        = number
  default     = 8
}

variable "validate_interval_seconds" {
  description = "Validation retry interval (seconds)"
  type        = number
  default     = 15
}

variable "alarm_evaluation_periods" {
  description = "Canary consecutive failure count for alarm"
  type        = number
  default     = 2
}

variable "discovery_targets" {
  description = "Discovery target Service Account list"
  type = list(object({
    account_id = string
    role_arn   = string
    region     = optional(string, "ap-northeast-2")
  }))
  default = []
}

variable "discovery_target_role_arns" {
  description = "Discovery Lambda assume role ARN list"
  type        = list(string)
  default     = []
}

variable "org_id" {
  description = "AWS Organization ID"
  type        = string
  default     = ""
}

variable "enable_scheduled_discovery" {
  description = "Enable scheduled auto-discovery"
  type        = bool
  default     = true
}

variable "discovery_schedule_expression" {
  description = "Discovery schedule expression"
  type        = string
  default     = "cron(0 21 * * ? *)"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  default     = ""
}

variable "enable_governance_pipeline" {
  description = "Enable governance pipeline"
  type        = bool
  default     = true
}

variable "governance_schedule_expression" {
  description = "Governance pipeline schedule"
  type        = string
  default     = "cron(0 0,12 * * ? *)"
}

variable "github_repo" {
  description = "GitHub repository for onboarding PRs"
  type        = string
  default     = ""
}

variable "report_timezone_offset" {
  description = "Report timezone UTC offset (hours)"
  type        = number
  default     = 9
}

variable "enable_enterprise_report" {
  description = "Enable enterprise report generation"
  type        = bool
  default     = true
}

variable "history_ttl_days" {
  description = "History table TTL (days)"
  type        = number
  default     = 180
}

variable "max_concurrent_failover" {
  description = "Max concurrent failovers (blast radius limit)"
  type        = number
  default     = 3
}

variable "verify_ssl" {
  description = "SSL verification (demo: false, production: true)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment (demo/staging/production)"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["demo", "staging", "production"], var.environment)
    error_message = "environment must be one of: demo, staging, production"
  }
}

variable "evidence_retention_days" {
  description = "Evidence S3 Object Lock retention (days)"
  type        = number
  default     = 365
}

variable "dashboard_enabled" {
  description = "CloudWatch Dashboard creation flag"
  type        = bool
  default     = true
}

variable "discovery_account_timeout" {
  description = "Discovery per-account scan timeout (seconds)"
  type        = number
  default     = 60
}

variable "token_validity_hours" {
  description = "Cognito token validity (hours)"
  type        = number
  default     = 8
}
