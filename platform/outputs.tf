output "failover_state_machine_arn" {
  value = { for k, v in aws_sfn_state_machine.failover : k => v.arn }
}

output "failback_state_machine_arn" {
  value = { for k, v in aws_sfn_state_machine.manual_failback : k => v.arn }
}

output "sns_topic_arn" {
  value = aws_sns_topic.notify.arn
}

output "audit_bucket_name" {
  value = aws_s3_bucket.audit.bucket
}

output "discovery_lambda_name" {
  value = aws_lambda_function.discovery.function_name
}

output "platform_lambda_role_arn" {
  value = aws_iam_role.failover_lambda.arn
}

output "discovery_lambda_role_arn" {
  value = aws_iam_role.discovery_lambda.arn
}

output "notification_email" {
  value = var.notification_email
}
