# S3 Audit Bucket
resource "aws_s3_bucket" "audit" {
  bucket_prefix = "${var.name_prefix}-audit-"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

# S3 Evidence Bucket (Object Lock — Immutable)
resource "aws_s3_bucket" "evidence" {
  bucket_prefix       = "${var.name_prefix}-evidence-"
  object_lock_enabled = true
  force_destroy       = false
  tags = merge(local.tags, { Purpose = "evidence-immutable" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_object_lock_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id
  rule { default_retention { mode = "GOVERNANCE"; days = var.evidence_retention_days } }
}

resource "aws_s3_bucket_versioning" "evidence" {
  bucket = aws_s3_bucket.evidence.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id
  rule {
    id     = "glacier-after-90-days"
    status = "Enabled"
    transition { days = 90; storage_class = "GLACIER" }
  }
}
