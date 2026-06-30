# -----------------------------
# Platform Account에 전달할 정보
# terraform_remote_state 또는 수동으로 platform/variables에 입력
# -----------------------------
output "service_name" {
  value = var.service_name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "domain_name" {
  value = var.domain_name
}

output "app_subdomain" {
  value = var.app_subdomain
}

output "hosted_zone_id" {
  value = aws_route53_zone.public.zone_id
}

output "hosted_zone_ns" {
  description = "V1 계정에서 NS 위임 시 이 값을 사용"
  value       = aws_route53_zone.public.name_servers
}

output "alb_arn" {
  value = aws_lb.app.arn
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_zone_id" {
  value = aws_lb.app.zone_id
}

output "alb_arn_suffix" {
  value = aws_lb.app.arn_suffix
}

output "cloudfront_dns_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_zone_id" {
  value = aws_cloudfront_distribution.cdn.hosted_zone_id
}

output "cloudfront_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.alb.arn
}

output "web_acl_name" {
  value = aws_wafv2_web_acl.alb.name
}

output "web_acl_id" {
  value = element(split("/", aws_wafv2_web_acl.alb.arn), 3)
}

output "emergency_sg_id" {
  value = aws_security_group.alb_emergency.id
}

output "cross_account_role_arn" {
  value = aws_iam_role.platform_trust.arn
}

output "discovery_role_arn" {
  value = aws_iam_role.discovery_trust.arn
}

output "app_url" {
  value = "https://${local.app_fqdn}"
}
