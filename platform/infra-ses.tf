# SES Email Identity for report delivery
variable "ses_from_email" {
  description = "SES verified sender email. Leave empty to disable."
  type        = string
  default     = ""
}

variable "ses_to_emails" {
  description = "Comma-separated recipient emails"
  type        = string
  default     = ""
}

variable "ses_domain" {
  description = "Domain for SES DKIM verification. Leave empty to skip."
  type        = string
  default     = ""
}

resource "aws_ses_email_identity" "report_sender" {
  count = var.ses_from_email != "" ? 1 : 0
  email = var.ses_from_email
}

resource "aws_ses_domain_identity" "report_domain" {
  count  = var.ses_domain != "" ? 1 : 0
  domain = var.ses_domain
}

resource "aws_ses_domain_dkim" "report_domain" {
  count  = var.ses_domain != "" ? 1 : 0
  domain = aws_ses_domain_identity.report_domain[0].domain
}
