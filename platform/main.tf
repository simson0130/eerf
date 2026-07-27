data "aws_caller_identity" "current" {}

locals {
  tags = {
    Layer       = "platform"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.name_prefix
  }

  # Production에서는 verify_ssl 강제 활성화 (변수값 무시)
  verify_ssl = var.environment == "production" ? true : var.verify_ssl

  # Environment 기반 기본값 조정
  is_production = var.environment == "production"
}
