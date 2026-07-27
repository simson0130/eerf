# Cognito User Pool — Portal Auth
resource "aws_cognito_user_pool" "portal" {
  name                     = "${var.name_prefix}-portal-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }
  admin_create_user_config {
    invite_message_template {
      email_subject = "[EERF Portal] Account Created"
      email_message = "EERF Portal access.\nEmail: {username}\nTemp Password: {####}\nChange on first login."
      sms_message   = "EERF ({username}) password: {####}"
    }
  }
  account_recovery_setting {
    recovery_mechanism { name = "verified_email"; priority = 1 }
  }
  schema { name = "email"; attribute_data_type = "String"; required = true; mutable = true }
  tags = local.tags
}

resource "aws_cognito_user_pool_client" "portal_spa" {
  name         = "${var.name_prefix}-portal-spa"
  user_pool_id = aws_cognito_user_pool.portal.id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  access_token_validity  = var.token_validity_hours
  id_token_validity      = var.token_validity_hours
  refresh_token_validity = 30
  token_validity_units { access_token = "hours"; id_token = "hours"; refresh_token = "days" }
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers = ["COGNITO"]
  callback_urls = ["http://localhost:5173/", "https://${aws_cloudfront_distribution.portal.domain_name}/"]
  logout_urls   = ["http://localhost:5173/", "https://${aws_cloudfront_distribution.portal.domain_name}/"]
}

resource "aws_cognito_user_pool_domain" "portal" {
  domain       = "${var.name_prefix}-portal"
  user_pool_id = aws_cognito_user_pool.portal.id
}

resource "aws_cognito_user_group" "admin" {
  name = "Admin"; user_pool_id = aws_cognito_user_pool.portal.id; description = "Full access"
}
resource "aws_cognito_user_group" "operator" {
  name = "Operator"; user_pool_id = aws_cognito_user_pool.portal.id; description = "Read + governance"
}
resource "aws_cognito_user_group" "readonly" {
  name = "ReadOnly"; user_pool_id = aws_cognito_user_pool.portal.id; description = "Read-only"
}

output "cognito_user_pool_id" { value = aws_cognito_user_pool.portal.id }
output "cognito_client_id" { value = aws_cognito_user_pool_client.portal_spa.id }
