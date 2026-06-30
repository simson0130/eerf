# =============================================================================
# services.tf — 서비스 설정 로딩 (services/*.json + var.services 병합)
# =============================================================================

locals {
  # services/ 디렉토리의 모든 JSON 파일을 로드
  _service_files = fileset("${path.module}/services", "*.json")

  _services_from_json = {
    for f in local._service_files :
    trimsuffix(f, ".json") => jsondecode(file("${path.module}/services/${f}"))
  }

  # var.services (tfvars)와 JSON 로드 결과를 merge
  # JSON 파일이 우선 (동일 key 존재 시 JSON 파일 값이 우선)
  services = merge(var.services, local._services_from_json)
}
