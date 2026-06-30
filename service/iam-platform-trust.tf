# -----------------------------
# Cross-Account Role: Platform Account가 assume
# Platform Lambda가 이 역할로 Route53, WAF, SG 조작
# -----------------------------
resource "aws_iam_role" "platform_trust" {
  name = "eerf-platform-trust"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.platform_account_id}:root" }
    }]
  })
  tags = local.tags
}

# -----------------------------
# Discovery Trust Role: Platform Discovery Lambda가 assume
# Route53, ELB, ACM, WAF 읽기 전용 (서비스 발견용)
# -----------------------------
resource "aws_iam_role" "discovery_trust" {
  name = "eerf-discovery-trust"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.platform_account_id}:root" }
      Condition = {
        StringEquals = {
          "aws:PrincipalAccount" = var.platform_account_id
        }
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "discovery_trust" {
  name = "eerf-discovery-trust-policy"
  role = aws_iam_role.discovery_trust.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:GetHostedZone"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACLForResource",
          "wafv2:GetWebACL"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:ListDistributions",
          "cloudfront:GetDistribution"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "platform_trust" {
  name = "${local.full_prefix}-platform-trust-policy"
  role = aws_iam_role.platform_trust.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${aws_route53_zone.public.zone_id}"
      },
      {
        Effect = "Allow"
        Action = ["wafv2:GetWebACL", "wafv2:UpdateWebACL"]
        Resource = [
          aws_wafv2_web_acl.alb.arn,
          "arn:aws:wafv2:${var.region}:${data.aws_caller_identity.current.account_id}:regional/managedruleset/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:SetSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
