# Route53 record: app.domain → CloudFront
# Failover 시 Platform Lambda가 이 레코드를 ALB DNS로 변경
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.public.zone_id
  name    = local.app_fqdn
  type    = "CNAME"
  ttl     = 60
  records = [aws_cloudfront_distribution.cdn.domain_name]
}
