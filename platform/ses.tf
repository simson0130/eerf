# =============================================================================
# SES Email Identity for HTML report delivery (Requirement 4.2)
# =============================================================================

variable "ses_from_email" {
  description = "SES verified sender email address for HTML reports. Leave empty to disable SES."
  type        = string
  default     = ""
}

variable "ses_to_emails" {
  description = "Comma-separated list of recipient email addresses for SES HTML reports"
  type        = string
  default     = ""
}

variable "ses_domain" {
  description = "Domain for SES DKIM verification. Removes [EXT UNVERIFIED SENDER] tag. Leave empty to skip."
  type        = string
  default     = ""
}

# SES Email Identity — only created when ses_from_email is configured
resource "aws_ses_email_identity" "report_sender" {
  count = var.ses_from_email != "" ? 1 : 0
  email = var.ses_from_email
}

# SES Domain Identity + DKIM — removes [EXT UNVERIFIED SENDER]
resource "aws_ses_domain_identity" "report_domain" {
  count  = var.ses_domain != "" ? 1 : 0
  domain = var.ses_domain
}

resource "aws_ses_domain_dkim" "report_domain" {
  count  = var.ses_domain != "" ? 1 : 0
  domain = aws_ses_domain_identity.report_domain[0].domain
}

# =============================================================================
# SES IAM Permission for Notification Lambda
# Only added when SES is configured
# =============================================================================

resource "aws_iam_role_policy" "notification_ses" {
  count = var.ses_from_email != "" ? 1 : 0
  name  = "${var.name_prefix}-notification-ses-policy"
  role  = aws_iam_role.notification_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}
