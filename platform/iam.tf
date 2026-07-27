# =============================================================================
# IAM — All Lambda Roles + Policy Attachments
# Policy JSON: iam/policies/*.json (templatefile)
# =============================================================================

locals {
  _iam_vars = {
    audit_bucket_arn        = aws_s3_bucket.audit.arn
    evidence_bucket_arn     = aws_s3_bucket.evidence.arn
    sns_topic_arn           = aws_sns_topic.notify.arn
    dynamodb_arn            = aws_dynamodb_table.services.arn
    dynamodb_stream_arn     = aws_dynamodb_table.services.stream_arn
    history_table_arn       = aws_dynamodb_table.history.arn
    region                  = var.region
    name_prefix             = var.name_prefix
    cross_account_role_arns = jsonencode([for svc in local.services : svc.cross_account_role_arn])
    cognito_user_pool_arn   = aws_cognito_user_pool.portal.arn
    canary_bucket_arn       = aws_s3_bucket.canary.arn
  }
}

# --- Failover/Failback/Validate (shared) ---
resource "aws_iam_role" "failover_lambda" {
  name               = "${var.name_prefix}-lambda-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "failover_lambda" {
  name   = "${var.name_prefix}-failover-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-failover.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "failover_lambda" {
  role       = aws_iam_role.failover_lambda.name
  policy_arn = aws_iam_policy.failover_lambda.arn
}

# --- Discovery ---
resource "aws_iam_role" "discovery_lambda" {
  name               = "${var.name_prefix}-discovery-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "discovery_lambda" {
  name   = "${var.name_prefix}-discovery-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-discovery.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "discovery_lambda" {
  role       = aws_iam_role.discovery_lambda.name
  policy_arn = aws_iam_policy.discovery_lambda.arn
}

# --- Evaluate ---
resource "aws_iam_role" "diff_engine_lambda" {
  name               = "${var.name_prefix}-diff-engine-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "diff_engine_lambda" {
  name   = "${var.name_prefix}-diff-engine-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-evaluate.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "diff_engine_lambda" {
  role       = aws_iam_role.diff_engine_lambda.name
  policy_arn = aws_iam_policy.diff_engine_lambda.arn
}

# --- Report ---
resource "aws_iam_role" "report_generator_lambda" {
  name               = "${var.name_prefix}-report-generator-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "report_generator_lambda" {
  name   = "${var.name_prefix}-report-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-report.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "report_generator_lambda" {
  role       = aws_iam_role.report_generator_lambda.name
  policy_arn = aws_iam_policy.report_generator_lambda.arn
}

# --- Notification ---
resource "aws_iam_role" "notification_lambda" {
  name               = "${var.name_prefix}-notification-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "notification_lambda" {
  name   = "${var.name_prefix}-notification-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-notification.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "notification_lambda" {
  role       = aws_iam_role.notification_lambda.name
  policy_arn = aws_iam_policy.notification_lambda.arn
}

# --- Stream History ---
resource "aws_iam_role" "stream_history" {
  name               = "${var.name_prefix}-stream-history-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "stream_history" {
  name   = "${var.name_prefix}-stream-history-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-stream-history.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "stream_history" {
  role       = aws_iam_role.stream_history.name
  policy_arn = aws_iam_policy.stream_history.arn
}

# --- Canary Health Sync ---
resource "aws_iam_role" "canary_health_sync" {
  name               = "${var.name_prefix}-canary-health-sync-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "canary_health_sync" {
  name   = "${var.name_prefix}-health-sync-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-health-sync.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "canary_health_sync" {
  role       = aws_iam_role.canary_health_sync.name
  policy_arn = aws_iam_policy.canary_health_sync.arn
}

# --- Token Rotation ---
resource "aws_iam_role" "token_rotation_lambda" {
  name               = "${var.name_prefix}-token-rotation-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "token_rotation_lambda" {
  name   = "${var.name_prefix}-token-rotation-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-token-rotation.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "token_rotation_lambda" {
  role       = aws_iam_role.token_rotation_lambda.name
  policy_arn = aws_iam_policy.token_rotation_lambda.arn
}

# --- API ---
resource "aws_iam_role" "api_lambda" {
  name               = "${var.name_prefix}-api-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "api_lambda" {
  name   = "${var.name_prefix}-api-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-api.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "api_lambda" {
  role       = aws_iam_role.api_lambda.name
  policy_arn = aws_iam_policy.api_lambda.arn
}

# --- Canary ---
resource "aws_iam_role" "canary" {
  name = "${var.name_prefix}-canary-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = ["lambda.amazonaws.com", "synthetics.amazonaws.com"] } }]
  })
  tags = local.tags
}
resource "aws_iam_policy" "canary" {
  name   = "${var.name_prefix}-canary-policy"
  policy = templatefile("${path.module}/iam/policies/canary.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "canary" {
  role       = aws_iam_role.canary.name
  policy_arn = aws_iam_policy.canary.arn
}

# --- Evidence ---
resource "aws_iam_role" "evidence_lambda" {
  name               = "${var.name_prefix}-evidence-role"
  assume_role_policy = file("${path.module}/iam/trust/lambda-assume-role.json")
  tags               = local.tags
}
resource "aws_iam_policy" "evidence_lambda" {
  name   = "${var.name_prefix}-evidence-policy"
  policy = templatefile("${path.module}/iam/policies/lambda-evidence.json", local._iam_vars)
  tags   = local.tags
}
resource "aws_iam_role_policy_attachment" "evidence_lambda" {
  role       = aws_iam_role.evidence_lambda.name
  policy_arn = aws_iam_policy.evidence_lambda.arn
}
