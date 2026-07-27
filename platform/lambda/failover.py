# See full implementation in local repo
# This file is the EERF Failover Lambda (Multi-Account, Unified)
# Key features:
# - DDB CONFIG-based service config loading
# - Cross-Account Role assume (STS)
# - Route53 CNAME change (CloudFront → ALB)
# - WAF mode transition (COUNT → BLOCK) with LockToken retry
# - ALB Emergency SG attachment
# - Partial failure rollback (transaction safety)
# - CORF Evidence Contract (before/after state capture)
# - Policy Gates (kill-switch, blast radius, governance)
# - FO Options per-service (waf_switch, sg_attach, waf_exclude_rules)
# - Idempotency check (skip if already in FO state)
# - MTTD calculation from Alarm state transition
# - Audit log (S3) + Alert notification (SES/SNS)
# - drill_active flag inheritance for FO/FB correlation

# Full source: ~400 lines
# Deployed via: platform/recover-lambda-failover.tf
