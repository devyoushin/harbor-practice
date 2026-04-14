# 이미지 스캐닝 (Trivy)

Harbor는 Trivy를 내장 스캐너로 사용해 컨테이너 이미지의 OS 패키지 및 라이브러리 취약점을 탐지합니다.

---

## 스캐닝 동작 원리

```
docker push → Harbor Registry
                    │
                    ▼
            [Jobservice] ─ 스캔 작업 큐잉
                    │
                    ▼
            [Trivy Adapter]
                    │
                    ├── 취약점 DB 업데이트 (ghcr.io/aquasecurity/trivy-db)
                    │
                    └── 이미지 레이어 분석 → CVE 매핑
                                │
                                ▼
                    결과 → Harbor DB 저장 → UI 표시
```

---

## Trivy 활성화 확인

```bash
# Trivy 파드 확인
kubectl get pods -n harbor | grep trivy

# Trivy가 스캐너로 등록되어 있는지 확인
curl -s "https://harbor.example.com/api/v2.0/scanners" \
  -u "admin:Harbor12345!" | jq '.[].name'
```

---

## 수동 스캔 실행

### UI에서 실행

1. **Projects** → 프로젝트 선택 → **Repositories**
2. 이미지 태그 옆 체크박스 선택
3. **SCAN** 버튼 클릭

### API로 실행

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# 특정 아티팩트 스캔
curl -s -X POST \
  "${HARBOR_URL}/api/v2.0/projects/backend/repositories/my-api/artifacts/v1.0.0/scan" \
  -u "${HARBOR_USER}:${HARBOR_PASS}"

# 프로젝트 전체 이미지 스캔
curl -s -X POST \
  "${HARBOR_URL}/api/v2.0/projects/backend/scan" \
  -u "${HARBOR_USER}:${HARBOR_PASS}"
```

---

## 자동 스캔 설정 (Push 시 자동 스캔)

### UI에서 설정

1. **Projects** → 해당 프로젝트 → **Configuration**
2. **Automatically scan images on push** 활성화

### API로 설정

```bash
curl -s -X PUT "${HARBOR_URL}/api/v2.0/projects/backend" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "metadata": {
      "auto_scan": "true"
    }
  }'
```

---

## 스캔 결과 확인

### UI에서 확인

**Projects** → **Repositories** → 이미지 태그 클릭 → **Vulnerabilities** 탭

결과 화면에서 확인 가능한 정보:
- CVE ID, 심각도 (Critical / High / Medium / Low / Negligible)
- 영향받는 패키지명, 현재 버전, 수정 버전
- CVE 설명 및 참고 링크

### API로 확인

```bash
# 스캔 결과 조회
curl -s \
  "${HARBOR_URL}/api/v2.0/projects/backend/repositories/my-api/artifacts/v1.0.0/additions/vulnerabilities" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq .

# Critical 취약점만 필터링
curl -s \
  "${HARBOR_URL}/api/v2.0/projects/backend/repositories/my-api/artifacts/v1.0.0/additions/vulnerabilities" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.["application/vnd.security.vulnerability.report; version=1.1"].vulnerabilities[]
        | select(.severity == "Critical")
        | {id: .id, package: .package, version: .version, fix_version: .fix_version}'
```

---

## 취약점 이미지 배포 차단 (Prevent Vulnerable Images)

특정 심각도 이상의 취약점이 있는 이미지를 Pull 단계에서 차단합니다.

### UI에서 설정

1. **Projects** → 해당 프로젝트 → **Configuration**
2. **Prevent vulnerable images from running** 활성화
3. 차단 기준 심각도 설정: `Critical` 권장

### 동작 확인

```bash
# 취약점이 있는 이미지 pull 시도 시
docker pull harbor.example.com/backend/vulnerable-image:latest
# Error response from daemon: unknown: Current image with 5 vulnerability is not allowed to pull due to configured policy.
```

---

## 취약점 허용 목록 (CVE Allowlist)

오탐이거나 현재 환경에서 실제 영향이 없는 CVE는 허용 목록에 추가할 수 있습니다.

### 시스템 전체 허용 목록

1. **Administration** → **Configuration** → **System Settings**
2. **CVE Allowlist** 섹션에서 CVE ID 추가

### 프로젝트별 허용 목록

1. **Projects** → 해당 프로젝트 → **Configuration**
2. **CVE Allowlist** 탭 → CVE ID 추가

```bash
# API로 프로젝트 CVE 허용 목록 설정
curl -s -X PUT "${HARBOR_URL}/api/v2.0/projects/backend" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "cve_allowlist": {
      "items": [
        {"cve_id": "CVE-2023-12345"},
        {"cve_id": "CVE-2023-67890"}
      ]
    }
  }'
```

---

## 취약점 DB 업데이트

Trivy는 주기적으로 취약점 DB를 자동 업데이트합니다.

```bash
# Trivy DB 업데이트 상태 확인
kubectl logs -n harbor -l component=trivy --tail=50 | grep -i "db"

# 수동으로 Trivy 재시작 (DB 즉시 갱신)
kubectl rollout restart deployment/harbor-trivy -n harbor
```

---

## 스캐닝 요약 통계

```bash
# 프로젝트 내 전체 취약점 요약
curl -s "${HARBOR_URL}/api/v2.0/projects/backend/repositories/my-api/artifacts" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.[] | {tag: .tags[0].name, scan_status: .scan_overview["application/vnd.security.vulnerability.report; version=1.1"].scan_status, critical: .scan_overview["application/vnd.security.vulnerability.report; version=1.1"].summary.fixable}'
```

---

## 외부 스캐너 연동 (선택)

Trivy 외에 Anchore, Clair 같은 외부 스캐너도 연동 가능합니다.

```bash
# 외부 스캐너 등록
curl -s -X POST "${HARBOR_URL}/api/v2.0/scanners" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Anchore",
    "url": "http://anchore-engine:8228",
    "auth": "BasicAuth",
    "access_credential": "admin:password"
  }'
```
