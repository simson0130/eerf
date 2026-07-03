# ADR-002: Discovery + Approval Model

## 상태: Accepted

## 결정

자동 발견(Discovery) + 인간 승인(Approval) 2단계 모델을 적용한다.

## 이유

- 자동 발견만으로는 보호 범위를 통제할 수 없음
- 모든 서비스를 무조건 보호하면 오탐/비용 문제
- 운영자가 승인한 서비스만 Canary/SFN 활성화
- 4상태 머신: Pending -> Approved / Deferred / Excluded
