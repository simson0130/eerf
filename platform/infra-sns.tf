# SNS Topic
resource "aws_sns_topic" "notify" {
  name = "${var.name_prefix}-notify"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.notify.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
