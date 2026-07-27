# =============================================================================
# Platform VPC — Canary VPC Mode (new VPC or existing subnets)
# =============================================================================

variable "canary_subnet_ids" {
  description = "Existing Private Subnet IDs (skip VPC creation if set)"
  type        = list(string)
  default     = []
}

variable "canary_security_group_id" {
  description = "Existing SG ID (skip SG creation if set)"
  type        = string
  default     = ""
}

resource "aws_vpc" "platform" {
  count                = length(var.canary_subnet_ids) == 0 ? 1 : 0
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${var.name_prefix}-platform-vpc" })
}

resource "aws_internet_gateway" "platform" {
  count  = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id = aws_vpc.platform[0].id
  tags = merge(local.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public_a" {
  count             = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id            = aws_vpc.platform[0].id
  cidr_block        = "10.0.0.0/27"
  availability_zone = "${var.region}a"
  tags = merge(local.tags, { Name = "${var.name_prefix}-public-a" })
}

resource "aws_subnet" "public_c" {
  count             = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id            = aws_vpc.platform[0].id
  cidr_block        = "10.0.0.32/27"
  availability_zone = "${var.region}c"
  tags = merge(local.tags, { Name = "${var.name_prefix}-public-c" })
}

resource "aws_subnet" "private_a" {
  count             = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id            = aws_vpc.platform[0].id
  cidr_block        = "10.0.0.64/26"
  availability_zone = "${var.region}a"
  tags = merge(local.tags, { Name = "${var.name_prefix}-private-a" })
}

resource "aws_subnet" "private_c" {
  count             = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id            = aws_vpc.platform[0].id
  cidr_block        = "10.0.0.128/26"
  availability_zone = "${var.region}c"
  tags = merge(local.tags, { Name = "${var.name_prefix}-private-c" })
}

resource "aws_eip" "nat_a" {
  count  = length(var.canary_subnet_ids) == 0 ? 1 : 0
  domain = "vpc"
  tags = merge(local.tags, { Name = "${var.name_prefix}-nat-eip-a" })
}

resource "aws_nat_gateway" "a" {
  count         = length(var.canary_subnet_ids) == 0 ? 1 : 0
  allocation_id = aws_eip.nat_a[0].id
  subnet_id     = aws_subnet.public_a[0].id
  tags = merge(local.tags, { Name = "${var.name_prefix}-nat-a" })
}

resource "aws_route_table" "public" {
  count  = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id = aws_vpc.platform[0].id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.platform[0].id }
  tags = merge(local.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table" "private_a" {
  count  = length(var.canary_subnet_ids) == 0 ? 1 : 0
  vpc_id = aws_vpc.platform[0].id
  route { cidr_block = "0.0.0.0/0"; nat_gateway_id = aws_nat_gateway.a[0].id }
  tags = merge(local.tags, { Name = "${var.name_prefix}-private-rt-a" })
}

resource "aws_route_table_association" "public_a" {
  count          = length(var.canary_subnet_ids) == 0 ? 1 : 0
  subnet_id      = aws_subnet.public_a[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private_a" {
  count          = length(var.canary_subnet_ids) == 0 ? 1 : 0
  subnet_id      = aws_subnet.private_a[0].id
  route_table_id = aws_route_table.private_a[0].id
}

resource "aws_route_table_association" "private_c" {
  count          = length(var.canary_subnet_ids) == 0 ? 1 : 0
  subnet_id      = aws_subnet.private_c[0].id
  route_table_id = aws_route_table.private_a[0].id
}

resource "aws_security_group" "canary" {
  count  = var.canary_security_group_id == "" ? 1 : 0
  name   = "${var.name_prefix}-canary-sg"
  vpc_id = length(var.canary_subnet_ids) == 0 ? aws_vpc.platform[0].id : null
  egress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTPS" }
  egress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTP" }
  tags = merge(local.tags, { Name = "${var.name_prefix}-canary-sg" })
}

locals {
  canary_subnet_ids = length(var.canary_subnet_ids) > 0 ? var.canary_subnet_ids : [
    aws_subnet.private_a[0].id,
    aws_subnet.private_c[0].id,
  ]
  canary_security_group_id = var.canary_security_group_id != "" ? var.canary_security_group_id : aws_security_group.canary[0].id
}
