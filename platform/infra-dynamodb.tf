# =============================================================================
# Infra - DynamoDB EERF Service Registry (SSOT)
# Single Table: PK=SERVICE#{key}, SK=CONFIG|GOVERNANCE|OPERATION|HEALTH
# GSI1: type-based queries, GSI2: account-based queries
# Streams: automatic audit trail
# =============================================================================

resource "aws_dynamodb_table" "services" {
  name         = "${var.name_prefix}-services"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute { name = "PK"; type = "S" }
  attribute { name = "SK"; type = "S" }
  attribute { name = "GSI1PK"; type = "S" }
  attribute { name = "GSI1SK"; type = "S" }
  attribute { name = "GSI2PK"; type = "S" }
  attribute { name = "GSI2SK"; type = "S" }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI2"
    hash_key        = "GSI2PK"
    range_key       = "GSI2SK"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  point_in_time_recovery { enabled = true }
  tags = merge(local.tags, { Purpose = "service-registry" })
}

# History Table (append-only, 180-day TTL)
resource "aws_dynamodb_table" "history" {
  name         = "${var.name_prefix}-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute { name = "PK"; type = "S" }
  attribute { name = "SK"; type = "S" }
  attribute { name = "GSI1PK"; type = "S" }
  attribute { name = "GSI1SK"; type = "S" }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  ttl { attribute_name = "ttl"; enabled = true }
  point_in_time_recovery { enabled = true }
  tags = merge(local.tags, { Purpose = "service-history" })
}

output "dynamodb_table_name" { value = aws_dynamodb_table.services.name }
output "dynamodb_table_arn" { value = aws_dynamodb_table.services.arn }
output "dynamodb_stream_arn" { value = aws_dynamodb_table.services.stream_arn }
output "dynamodb_history_table_name" { value = aws_dynamodb_table.history.name }
