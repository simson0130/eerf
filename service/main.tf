locals {
  app_fqdn    = "${var.app_subdomain}.${var.domain_name}"
  origin_fqdn = "${var.origin_subdomain}.${var.domain_name}"
  full_prefix = "${var.name_prefix}-${var.service_name}"
  tags = {
    Project = var.name_prefix
    Service = var.service_name
    Managed = "terraform"
    Layer   = "service"
  }
}

# Hosted Zone 생성 (Service Account 소유)
resource "aws_route53_zone" "public" {
  name    = var.domain_name
  comment = "EERF Service Zone for ${var.service_name}"
  tags    = local.tags
}

data "aws_caller_identity" "current" {}
