# Changelog

## [v0.6.0] — 2026-07-22 Code Quality + Documentation Restructure

### Added
- API Router pattern (routes/router.py — regex-based dispatch, 37 routes)
- Lambda zip split (api_lambda.zip independent package — Cold start improvement)
- `environment` variable (demo/staging/production) + verify_ssl enforcement
- DAL unit test 24 (moto: CONFIG, GOVERNANCE OCC, OPERATION drill, HEALTH, Policy)
- Failover Safety Gate test 5 (kill-switch, blast radius, governance gate)
- docs/ restructure (00-product ~ 05-decisions numbered folders)

### Changed
- api.py: if/elif 200 lines → Router table + thin wrappers
- api.py: all path params validated via _extract_service_key
- dal.py: put_policy_rules/override JSON serialization (DDB float error fix)
- services.tf: example-service.json load excluded (unnecessary resource prevention)
- main.tf: local.verify_ssl (production forces true)
- detect-canary.tf, recover-lambda-failover.tf: local.verify_ssl reference

### Removed
- platform/lambda/diff_engine.py (removed from SFN on 07-11, file lingered)
- platform/canary/canary.js (legacy, Python migration complete)
- platform/out-dash.json, plan_output.txt, validate_result.txt, tfplan (temp files)
- platform/services/app-srv2-XXXX.json.template (replaced by example-service.json)

### Fixed
- docs/ Korean encoding broken in 10 files (full UTF-8 rewrite)
- docs/ CLI legacy content removed → Portal-centric operations

---

## [v0.5.0] — 2026-07-21 Phase 4: Production Ready (CORF Compliant)

### Added
- CORF 7-stage Lifecycle complete (Discover→Evaluate→Approve→Protect→Recover→Restore→Operate)
- Policy Decision Lambda (criticality + maintenance window + correlated failure)
- Canary custom metrics (CDN/Origin Health per-service, eerf/Canary namespace)
- CloudWatch Dashboard CDN/Origin Health timeSeries widgets (Row 4)
- `verify_ssl` variable (demo: false, production: true)
- SFN TimeoutSeconds = 300 (FO/FB infinite execution prevention)
- API Gateway WAF WebACL + Usage Plan (rate limit: burst=50, rate=20/s)
- Portal 19 pages (ExcludedServices, ServiceSettings, etc.)
- approved → protected auto-promotion (evaluate.py: all items pass + Canary/SFN/Alarm exist)
- auto-suspend / auto-unsuspend (readiness unmet → auto block/restore)
- drill ≠ incident full separation (drill_active preset + correlation_id)
- DDB Zero SCAN (GSI1 Query + pagination + ProjectionExpression)
- 500 service scaling (batch describe 100ea, DAL pagination)
- CORF docs 5 (philosophy, lifecycle, compliance, principles, roadmap)
- ADR-007: CORF adoption

### Changed
- IAM least privilege: SES `*` → identity scope, SFN `*` → name_prefix scope
- CORS: `*` → Portal CloudFront domain fixed (ALLOWED_ORIGIN env var)
- Portal FO/FB: DangerConfirmDialog (service name input confirmation)
- Failback: cooling period 5min consecutive healthy required
- api.py: 27+ endpoints, input validation, evaluate/run added
- diff_engine.py removed (separated from SFN pipeline)

---

## [v0.4.0] — 2026-07-06 Phase 5a: DDB SSOT + Enterprise Production Ready

### Added
- DynamoDB 4-axis state model (GOVERNANCE/OPERATION/HEALTH/CONFIG)
- DAL common module (dal.py) + Optimistic Locking
- DDB Stream → eerf-history automatic history (stream_history.py)
- Canary Health Sync Lambda (canary_health_sync.py, 5min interval)
- Enterprise Report Lambda (report_enterprise.py)
- Unified alert module (alert.py, 18 AlertTypes)
- CloudWatch PutMetricData permission + custom metrics

---

## [v0.3.0] — 2026-06-30 Phase 4: Alert/Status Complete + Operations Stabilization

### Added
- eerf reopen CLI command
- Operator auto-identification (STS GetCallerIdentity)
- All state changes → immediate SNS→SES email alerts
- CloudWatch metrics immediate publish
- Dashboard 4-quadrant widgets
- EventBridge SFN failure alerts (FAILED/TIMED_OUT → SNS)

---

## [v0.2.0] — 2026-06-26 Platform/Service Account Separation

### Added
- Platform / Service Account separation architecture
- Cross-Account IAM (Discovery Trust + Platform Trust)
- Discovery Lambda (auto-discover existing services)
- for_each multi-service management
- CloudWatch Dashboard (per-service widgets)

---

## [v0.1.0] — 2026-06-25 PoC

### Added
- CloudFront single-account PoC
- Auto Failover: Canary → Alarm → EventBridge → Step Functions → Lambda
- Auto Failback: Manual Failback Step Functions
- DNS validation + auto rollback
- WAF COUNT → BLOCK auto transition
- ALB Emergency SG dynamic attach
- CloudWatch Synthetics Canary (CDN + Origin dual verification)
- S3 audit log + SNS alerts
- CloudWatch Dashboard
