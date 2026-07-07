# EERF Installation Guide

---

## 사전 요구사항

| 항목 | 요구 |
|------|------|
| Platform Account | Lambda, SFN, Synthetics, EventBridge, SNS, S3, DynamoDB, STS |
| Service Account | 기존 운영 인프라 + IAM Role 생성 권한 |
| Terraform | >= 1.5 |
| AWS CLI | v2 |
| Python | >= 3.10 (eerf-cli용) |

---

## eerf-cli 설치

```powershell
cd tools/eerf-cli
pip install -e .
eerf --help
```

---

## 최초 Platform 계정 배포

### Step 1: S3 State 버킷 + DynamoDB Lock 생성

```powershell
aws s3api create-bucket --bucket eerf-terraform-state-{ACCOUNT_ID} --region ap-northeast-2 --create-bucket-configuration LocationConstraint=ap-northeast-2
aws s3api put-bucket-versioning --bucket eerf-terraform-state-{ACCOUNT_ID} --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name eerf-terraform-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region ap-northeast-2
```

### Step 2: providers.tf 수정

```hcl
terraform {
  backend "s3" {
    bucket       = "eerf-terraform-state-{YOUR_ACCOUNT_ID}"
    key          = "platform/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
  }
}
```

### Step 3: terraform.tfvars 작성

```hcl
region             = "ap-northeast-2"
name_prefix        = "eerf"
notification_email = "ops@yourcompany.com"
org_id             = "o-XXXXXXXXXX"
ses_from_email     = "eerf@yourcompany.com"
ses_to_emails      = "ops@yourcompany.com"
```

### Step 4: 배포

```powershell
cd platform
terraform init
terraform apply -var-file="terraform.tfvars.shared"
```

### Step 5: Service Account Trust Role

```powershell
..\tools\create-trust-roles.ps1
```

### Step 6: 검증

```powershell
eerf --bucket <bucket> status
```
