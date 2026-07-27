terraform {
  backend "s3" {
    bucket         = "eerf-terraform-state-665989470268"
    key            = "platform/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "eerf-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Service     = "eerf"
      Department  = "proserve"
      Environment = "prod"
      ManagedBy   = "terraform"
      Project     = "eerf"
    }
  }
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"

  default_tags {
    tags = {
      Service     = "eerf"
      Department  = "proserve"
      Environment = "prod"
      ManagedBy   = "terraform"
      Project     = "eerf"
    }
  }
}
