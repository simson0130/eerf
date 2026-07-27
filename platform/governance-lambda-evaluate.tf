# Evaluate Lambda (Readiness Score + Auto Promote/Suspend)
data "archive_file" "evaluate_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/evaluate.zip"
  excludes    = ["tests", "tests/**", "__pycache__", "__pycache__/**", ".pytest_cache/**"]
}

resource "aws_lambda_function" "evaluate" {
  function_name    = "${var.name_prefix}-evaluate"
  role             = aws_iam_role.diff_engine_lambda.arn
  handler          = "evaluate.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.evaluate_lambda.output_path
  source_code_hash = data.archive_file.evaluate_lambda.output_base64sha256
  timeout          = 120
  memory_size      = 256
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.services.name
      HISTORY_TABLE  = aws_dynamodb_table.history.name
      NAME_PREFIX    = var.name_prefix
      SNS_TOPIC_ARN  = aws_sns_topic.notify.arn
    }
  }
  tags = local.tags
}
