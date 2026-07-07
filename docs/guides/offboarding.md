# EERF 삭제 (보호 해제) 가이드

---

## Step 1: 서비스 제외

```powershell
eerf --bucket <bucket> exclude <key> --reason "보호 해제"
```

---

## Step 2: JSON 삭제 + Apply

```powershell
Remove-Item platform/services/{key}.json
terraform apply -var-file="terraform.tfvars.shared"
```

---

## 재등록

```powershell
eerf --bucket <bucket> reopen <key> --reason "재검토"
```
