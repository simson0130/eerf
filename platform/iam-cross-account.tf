# Platform Lambda Execution Role (Cross-Account)
resource "aws_iam_role" "failover_lambda" {
  name = "${var.name_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "failover_lambda_base" {
  name = "${var.name_prefix}-lambda-base-policy"
  role = aws_iam_role.failover_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.audit.arn}/*" },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.notify.arn },
      { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = "arn:aws:ssm:${var.region}:*:parameter/${var.name_prefix}/canary/*" }
    ]
  })
}

resource "aws_iam_role_policy" "failover_lambda_cross_account" {
  name = "${var.name_prefix}-lambda-cross-account-policy"
  role = aws_iam_role.failover_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = [for svc in var.services : svc.cross_account_role_arn]
    }]
  })
}
