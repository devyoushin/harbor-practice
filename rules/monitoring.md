# 모니터링 지침 — harbor-practice

## 헬스 체크

```bash
# Harbor 전체 상태
curl -u admin:<pw> https://harbor.example.com/api/v2.0/health

# 컴포넌트별 상태
kubectl get pods -n harbor
kubectl top pods -n harbor

# PVC 용량
kubectl get pvc -n harbor
```

## 스토리지 모니터링

```bash
# S3 버킷 사용량 (AWS CLI)
aws s3 ls s3://<bucket> --recursive --summarize | tail -2

# Harbor 디스크 사용량 (API)
curl -u admin:<pw> https://harbor.example.com/api/v2.0/systeminfo \
  | jq '.storage'
```

## 스캔 현황

```bash
# 취약점 통계 (프로젝트별)
curl -u admin:<pw> \
  "https://harbor.example.com/api/v2.0/projects/<project>/summary" \
  | jq '.vulnerability_total'
```

## 핵심 알람

| 항목 | 조건 | 대응 |
|------|------|------|
| PVC 사용률 | > 80% | 가비지 컬렉션 또는 PVC 확장 |
| S3 비용 | 월 예산 초과 | 보존 정책 강화 |
| TLS 만료 | D-30 | 인증서 갱신 |
| Critical 취약점 | 신규 발견 | 이미지 업데이트 |

## 가비지 컬렉션

```
- 스케줄: 매주 일요일 00:00 (서비스 저부하 시간)
- 실행 중 Push 불가 → 새벽 실행 권장
- 실행 전 스냅샷 백업 권장
```
