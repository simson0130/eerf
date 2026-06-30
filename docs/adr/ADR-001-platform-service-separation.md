# ADR-001: Platform / Service Account 분리

## Status
Accepted

## Context
단일 계정 PoC(v0.1)에서는 모든 리소스가 하나의 AWS 계정에 존재했다. 엔터프라이즈 환경에서는 수백 개 서비스가 각기 다른 계정에서 운영되며, 오케스트레이션과 서비스 인프라의 소유권이 분리되어야 한다.

## Decision
- **Platform Account**: Discovery, Canary, Alarm, Step Functions, Lambda (오케스트레이션 전용)
- **Service Account(s)**: VPC, ALB, WAF, CloudFront, EC2/ECS (서비스 인프라)
- **CloudFront는 Service Account 소유**: 현실적으로 각 서비스 팀이 자기 도메인에 CDN을 붙여 운영
- Platform은 Cross-Account AssumeRole로 Service Account 리소스를 조작

## Consequences
- (+) 권한 분리: Platform은 오케스트레이션만
- (+) 멀티 서비스 확장: services map에 항목 추가만으로 온보딩
- (+) 감사 추적: AssumeRole 기록이 CloudTrail에 남음
- (-) 복잡도 증가: Cross-Account IAM 설정 필요

## Alternatives Considered
- **단일 계정 유지**: 대규모 환경에서 관리 불가
- **CloudFront를 Platform 소유**: 현실에 안 맞음
- **AWS RAM 공유**: Route53, WAF는 RAM 지원 안 함
