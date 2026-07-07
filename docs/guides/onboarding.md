# EERF 온보딩 가이드

> 소요시간: ~10분

---

## Step 1: 서비스 승인

```powershell
eerf --bucket <bucket> approve <key> --reason "보호 대상"
```

---

## Step 2: services.json 생성

`platform/services/{key}.json` 생성 (템플릿 참조)

---

## Step 3: Terraform Apply

```powershell
cd platform
terraform apply -var-file="terraform.tfvars.shared"
```

---

## Step 4: 검증

```powershell
..\tools\demo-platform.ps1 -Action verify -ServiceKey <key>
```
