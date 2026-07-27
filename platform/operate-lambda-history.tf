# Stream History Lambda (DDB Streams → History)
data "archive_file" "stream_history" {
  type        = "zip"
  source_file = "${path.module}/lambda/stream_history.py"
  output_path = "${path.module}/.build/stream_history.zip"
}

resource "aws_lambda_function" "stream_history" {
  function_name    = "${var.name_prefix}-stream-history"
  filename         = data.archive_file.stream_history.output_path
  source_code_hash = data.archive_file.stream_history.output_base64sha256
  handler          = "stream_history.handler"
  runtime          = "python3.13"
  timeout          = 60
  memory_size      = 128
  role             = aws_iam_role.stream_history.arn
  environment {
    variables = { HISTORY_TABLE = aws_dynamodb_table.history.name; SNS_TOPIC_ARN = aws_sns_topic.notify.arn }
  }
  tags = merge(local.tags, { Purpose = "stream-history" })
}

resource "aws_lambda_event_source_mapping" "stream_history" {
  event_source_arn       = aws_dynamodb_table.services.stream_arn
  function_name          = aws_lambda_function.stream_history.arn
  starting_position      = "LATEST"
  batch_size             = 25
  maximum_retry_attempts = 3
  depends_on             = [aws_iam_role_policy_attachment.stream_history]
}
