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
  }))
  default = {}
}

variable "canary_schedule_expression" {
  description = "CloudWatch Synthetics canary schedule"
  type        = string
  default     = "rate(1 minute)"
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
  description = "Service Account Role ARN list for Discovery Lambda"
  type        = list(string)
  default     = []
}

variable "org_id" {
  description = "AWS Organization ID"
  type        = string
  default     = ""
}

variable "enable_scheduled_discovery" {
  type    = bool
  default = true
}

variable "discovery_schedule_expression" {
  type    = string
  default = "cron(0 21 * * ? *)"
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL"
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
  default     = "cron(0 * * * ? *)"
}

variable "report_timezone_offset" {
  description = "Report timezone UTC offset (hours). Default KST = 9"
  type        = number
  default     = 9
}
