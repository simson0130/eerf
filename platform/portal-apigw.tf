# Portal API Gateway REST API
resource "aws_api_gateway_rest_api" "portal" {
  name = "${var.name_prefix}-portal-api"
  endpoint_configuration { types = ["REGIONAL"] }
  tags = local.tags
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.name_prefix}-cognito-auth"
  rest_api_id     = aws_api_gateway_rest_api.portal.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [aws_cognito_user_pool.portal.arn]
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  parent_id   = aws_api_gateway_rest_api.portal.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.portal.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.portal.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# CORS OPTIONS
resource "aws_api_gateway_method" "proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.portal.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Deployment + Stage
resource "aws_api_gateway_deployment" "portal" {
  rest_api_id = aws_api_gateway_rest_api.portal.id
  depends_on  = [aws_api_gateway_integration.proxy, aws_api_gateway_integration.proxy_options]
  triggers    = { redeployment = sha1(jsonencode([aws_api_gateway_resource.proxy.id, aws_api_gateway_method.proxy.id])) }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.portal.id
  rest_api_id   = aws_api_gateway_rest_api.portal.id
  stage_name    = "prod"
  tags          = local.tags
}

output "api_url" { value = "${aws_api_gateway_stage.prod.invoke_url}/api" }
