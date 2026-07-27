# Portal API Lambda (slim package for fast cold start)
data "archive_file" "api_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  excludes = [
    "tests/**", "__pycache__/**", "*.pyc", ".pytest_cache/**",
    "failover.py", "failback.py", "dns_validate.py",
    "discovery.py", "evaluate.py", "evidence_record.py",
    "canary_health_sync.py", "stream_history.py",
    "report_generator.py", "report_enterprise.py",
    "notification.py", "policy_decision.py", "token_rotation.py",
  ]
  output_path = "${path.module}/.build/api_lambda.zip"
}

resource "aws_lambda_function" "api" {
  function_name    = "${var.name_prefix}-api"
  role             = aws_iam_role.api_lambda.arn
  handler          = "api.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.api_lambda.output_path
  source_code_hash = data.archive_file.api_lambda.output_base64sha256
  timeout          = 30
  memory_size      = 256
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
      HISTORY_TABLE  = aws_dynamodb_table.history.name
      AUDIT_BUCKET   = aws_s3_bucket.audit.bucket
      SNS_TOPIC_ARN  = aws_sns_topic.notify.arn
      NAME_PREFIX    = var.name_prefix
      USER_POOL_ID   = aws_cognito_user_pool.portal.id
      ALLOWED_ORIGIN = "https://${aws_cloudfront_distribution.portal.domain_name}"
      ORG_ID         = var.org_id
      ENVIRONMENT    = var.environment
    }
  }
  tags = local.tags
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.portal.execution_arn}/*/*"
}
