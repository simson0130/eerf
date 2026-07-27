# Policy Decision Lambda
data "archive_file" "policy_decision_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/policy_decision.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache/**"]
}

resource "aws_lambda_function" "policy_decision" {
  function_name    = "${var.name_prefix}-policy-decision"
  role             = aws_iam_role.policy_decision_lambda.arn
  handler          = "policy_decision.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.policy_decision_lambda.output_path
  source_code_hash = data.archive_file.policy_decision_lambda.output_base64sha256
  timeout          = 30
  memory_size      = 256
  environment {
    variables = {
      DYNAMODB_TABLE          = aws_dynamodb_table.services.name
      NAME_PREFIX             = var.name_prefix
      MAX_CONCURRENT_FAILOVER = tostring(var.max_concurrent_failover)
      SNS_TOPIC_ARN           = aws_sns_topic.notify.arn
    }
  }
  tags = local.tags
}

resource "aws_iam_role" "policy_decision_lambda" {
  name               = "${var.name_prefix}-policy-decision-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}

resource "aws_iam_role_policy" "policy_decision_lambda" {
  name = "${var.name_prefix}-policy-decision-policy"
  role = aws_iam_role.policy_decision_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"], Resource = [aws_dynamodb_table.services.arn, "${aws_dynamodb_table.services.arn}/index/*"] },
      { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/*" },
      { Effect = "Allow", Action = ["states:StartExecution"], Resource = "arn:aws:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.name_prefix}-*-failover" },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.notify.arn },
      { Effect = "Allow", Action = ["sts:GetCallerIdentity"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
    ]
  })
}
