# Evidence Record Lambda
resource "aws_lambda_function" "evidence_record" {
  function_name    = "${var.name_prefix}-evidence-record"
  role             = aws_iam_role.evidence_lambda.arn
  handler          = "evidence_record.handler"
  runtime          = "python3.13"
  filename         = data.archive_file.platform_lambda.output_path
  source_code_hash = data.archive_file.platform_lambda.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment {
    variables = {
      HISTORY_TABLE   = aws_dynamodb_table.history.name
      AUDIT_BUCKET    = aws_s3_bucket.audit.bucket
      EVIDENCE_BUCKET = aws_s3_bucket.evidence.bucket
      NAME_PREFIX     = var.name_prefix
      DYNAMODB_TABLE  = aws_dynamodb_table.services.name
    }
  }
  tags = merge(local.tags, { Purpose = "evidence-record" })
}
