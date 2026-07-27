# Portal S3 + CloudFront + OAC (Static Hosting)
resource "aws_s3_bucket" "portal" {
  bucket = "${var.name_prefix}-portal-${data.aws_caller_identity.current.account_id}"
  tags   = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "portal" {
  bucket = aws_s3_bucket.portal.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_public_access_block" "portal" {
  bucket = aws_s3_bucket.portal.id
  block_public_acls = true; block_public_policy = true
  ignore_public_acls = true; restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "portal" {
  bucket = aws_s3_bucket.portal.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "AllowCloudFrontOAC"; Effect = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action = "s3:GetObject"; Resource = "${aws_s3_bucket.portal.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.portal.arn } }
    }]
  })
}

resource "aws_cloudfront_origin_access_control" "portal" {
  name                              = "${var.name_prefix}-portal-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "portal" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "EERF Portal (React SPA)"
  price_class         = "PriceClass_200"
  http_version        = "http2and3"

  origin {
    domain_name              = aws_s3_bucket.portal.bucket_regional_domain_name
    origin_id                = "s3-portal"
    origin_access_control_id = aws_cloudfront_origin_access_control.portal.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-portal"
    forwarded_values { query_string = false; cookies { forward = "none" } }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0; default_ttl = 300; max_ttl = 86400; compress = true
  }

  custom_error_response { error_code = 403; response_code = 200; response_page_path = "/index.html" }
  custom_error_response { error_code = 404; response_code = 200; response_page_path = "/index.html" }

  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-portal"
    forwarded_values { query_string = false; cookies { forward = "none" } }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 86400; default_ttl = 604800; max_ttl = 2592000; compress = true
  }

  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
  tags = local.tags
}

output "portal_url" { value = "https://${aws_cloudfront_distribution.portal.domain_name}" }
output "portal_bucket" { value = aws_s3_bucket.portal.bucket }
output "portal_distribution_id" { value = aws_cloudfront_distribution.portal.id }
