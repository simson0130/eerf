variable "region" {
  description = "AWS region for this service account"
  type        = string
  default     = "ap-northeast-2"
}

variable "name_prefix" {
  description = "Resource naming prefix for this service"
  type        = string
  default     = "eerf"
}

variable "service_name" {
  description = "Logical name of this service (e.g., app1, portal, api)"
  type        = string
}

variable "domain_name" {
  description = "Route 53 public hosted zone domain"
  type        = string
}

variable "app_subdomain" {
  description = "Application subdomain"
  type        = string
  default     = "app"
}

variable "origin_subdomain" {
  description = "Direct origin subdomain (optional, for testing)"
  type        = string
  default     = "origin-app"
}

variable "enable_cloudfront_breaker" {
  description = "When true, changes CloudFront origin to a dead endpoint to simulate CDN path failure."
  type        = bool
  default     = false
}

# -----------------------------
# Platform Account 연동
# -----------------------------
variable "platform_account_id" {
  description = "AWS Account ID of the Platform Account (for IAM trust)"
  type        = string
}

variable "platform_lambda_role_arn" {
  description = "ARN of the Platform Lambda execution role that will assume into this account"
  type        = string
}
