# =============================================================================
# services.tf - Service configuration loading (services/*.json + var.services)
# =============================================================================

locals {
  _service_files = [
    for f in fileset("${path.module}/services", "*.json") :
    f if !startswith(f, "example-")
  ]

  _services_from_json = {
    for f in local._service_files :
    trimsuffix(f, ".json") => jsondecode(file("${path.module}/services/${f}"))
  }

  _services_raw = merge(var.services, local._services_from_json)

  services = {
    for k, v in local._services_raw : k => merge(v, {
      canary_health_path     = try(v.canary_health_path, "/health")
      canary_cdn_port        = try(v.canary_cdn_port, 443)
      canary_cdn_protocol    = try(v.canary_cdn_protocol, "https")
      canary_origin_port     = try(v.canary_origin_port, 80)
      canary_origin_protocol = try(v.canary_origin_protocol, "http")
    })
  }
}
