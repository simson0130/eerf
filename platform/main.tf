locals {
  tags = {
    Project = var.name_prefix
    Managed = "terraform"
    Layer   = "platform"
  }
}
