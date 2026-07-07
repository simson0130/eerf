# EERF FO/FB 데모 가이드

> CloudFront를 외부 CDN(Cloudflare) 역할로 사용하는 데모 환경

---

## 타임라인

```
T+0     CDN Origin 변경 (break)
T+10분  CF 전파 완료
T+12분  Canary 2회 FAILED → Alarm ALARM
T+13분  SFN → Failover Lambda
T+15분  DNS Validate → Complete
```

---

## 0단계: 상태 확인 + Watch

```powershell
# Platform
..\tools\demo-platform.ps1 -Action status -FQDN app.srv1.example.com
..\tools\demo-platform.ps1 -Action watch -FQDN app.srv1.example.com

# Service
..\tools\demo-service.ps1 -Action status -FQDN app.srv1.example.com
```

---

## 1단계: CDN 장애 시뮬레이션

```powershell
..\tools\demo-service.ps1 -Action break -FQDN app.srv1.example.com
```

---

## 2단계: Watch 관찰

Canary FAILED → Alarm ALARM → SFN SUCCEEDED

---

## 3단계: FO 확인

```powershell
eerf --bucket <bucket> status
eerf --bucket <bucket> history <key> -n 5
```

---

## 4단계: CDN 복원 + Failback

```powershell
..\tools\demo-service.ps1 -Action restore -FQDN app.srv1.example.com
# 5~10분 대기
..\tools\safe-failback.ps1 -ServiceName <key> -CdnUrl "https://<cf-domain>/health"
```

---

## 성공 기준

- OPERATION: standby → failover → standby
- History 기록 확인
- 이메일 2통 (FO + FB)
