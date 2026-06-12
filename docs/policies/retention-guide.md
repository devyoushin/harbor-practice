# Tag 보존 정책 (Retention Policy)

오래된 이미지 태그를 자동으로 정리해 Registry 스토리지를 효율적으로 관리합니다.

---

## 왜 Tag 보존 정책이 필요한가?

CI/CD 파이프라인이 활발하면 하루에도 수십 개의 이미지 태그가 쌓입니다.

```
harbor.example.com/backend/my-api
├── latest
├── v1.0.0
├── v1.0.1
├── sha-abc1234  ← CI 커밋별 태그
├── sha-def5678
├── sha-ghi9012
...
├── sha-xyz9999  ← 수백 개의 사용하지 않는 태그
```

보존 정책을 설정하면 규칙에 맞는 태그만 유지하고 나머지를 자동 삭제합니다.

---

## 보존 규칙 구성

보존 정책은 **포함(retain)** 또는 **제외(exclude)** 규칙의 조합입니다.

| 규칙 유형 | 설명 |
|---|---|
| `latestPushedK` | 최근 Push된 K개 태그 유지 |
| `latestActiveK` | 최근 Pull된 K개 태그 유지 |
| `nDaysSinceLastPush` | 마지막 Push 후 N일 이내 태그 유지 |
| `nDaysSinceLastPull` | 마지막 Pull 후 N일 이내 태그 유지 |
| `always` | 태그 패턴 매칭 시 항상 유지 |
| `nothing` | 태그 패턴 매칭 시 항상 삭제 |

---

## UI에서 보존 정책 설정

1. **Projects** → 해당 프로젝트 → **Policy** → **TAG RETENTION**
2. **ADD RULE** 클릭
3. 규칙 구성:

```
Repositories matching: **                      (모든 Repository)
태그 매칭: **                                  (모든 태그)
조건: Retain the most recently pushed # artifacts  → 10개
```

4. 다중 규칙 예시:

```
규칙 1: 태그가 'v*' 패턴인 이미지는 항상 유지 (릴리즈 버전)
규칙 2: 태그가 'sha-*' 패턴인 이미지는 최근 10개만 유지 (CI 빌드)
규칙 3: 태그가 'latest' 패턴인 이미지는 항상 유지
```

---

## API로 보존 정책 설정

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# 프로젝트 ID 확인
PROJECT_ID=$(curl -s "${HARBOR_URL}/api/v2.0/projects?name=backend" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[0].id')

# 보존 정책 생성
curl -s -X POST "${HARBOR_URL}/api/v2.0/retentions" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"algorithm\": \"or\",
    \"rules\": [
      {
        \"disabled\": false,
        \"action\": \"retain\",
        \"template\": \"always\",
        \"tag_selectors\": [
          {
            \"kind\": \"doublestar\",
            \"decoration\": \"matches\",
            \"pattern\": \"v*\"
          }
        ],
        \"scope_selectors\": {
          \"repository\": [
            {
              \"kind\": \"doublestar\",
              \"decoration\": \"repoMatches\",
              \"pattern\": \"**\"
            }
          ]
        }
      },
      {
        \"disabled\": false,
        \"action\": \"retain\",
        \"template\": \"latestPushedK\",
        \"params\": {\"latestPushedK\": 10},
        \"tag_selectors\": [
          {
            \"kind\": \"doublestar\",
            \"decoration\": \"matches\",
            \"pattern\": \"sha-*\"
          }
        ],
        \"scope_selectors\": {
          \"repository\": [
            {
              \"kind\": \"doublestar\",
              \"decoration\": \"repoMatches\",
              \"pattern\": \"**\"
            }
          ]
        }
      }
    ],
    \"trigger\": {
      \"kind\": \"Schedule\",
      \"settings\": {
        \"cron\": \"0 0 0 * * *\"
      }
    },
    \"scope\": {
      \"level\": \"project\",
      \"ref\": ${PROJECT_ID}
    }
  }"
```

---

## Dry Run (삭제 전 미리 보기)

실제 삭제 전에 어떤 태그가 삭제될지 확인합니다.

```bash
# 현재 정책 ID 확인
RETENTION_ID=$(curl -s "${HARBOR_URL}/api/v2.0/projects/${PROJECT_ID}" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.metadata.retention_id')

# Dry Run 실행
curl -s -X POST "${HARBOR_URL}/api/v2.0/retentions/${RETENTION_ID}/executions" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true}'

# 실행 결과 확인
EXEC_ID=1
curl -s "${HARBOR_URL}/api/v2.0/retentions/${RETENTION_ID}/executions/${EXEC_ID}/tasks" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[].status_reason'
```

---

## 보존 정책 스케줄

| Cron 표현식 | 실행 주기 |
|---|---|
| `0 0 0 * * *` | 매일 자정 |
| `0 0 1 * * 0` | 매주 일요일 새벽 1시 |
| `0 0 2 1 * *` | 매월 1일 새벽 2시 |

---

## 권장 정책 패턴

### 개발 환경

```
- v* 태그: 항상 유지 (릴리즈 버전)
- latest: 항상 유지
- 그 외: 최근 Push 10개만 유지
- 실행 주기: 매일
```

### 운영 환경

```
- v[0-9]*.[0-9]*.[0-9]* 태그: 항상 유지 (SemVer 릴리즈)
- rc-*, beta-*: 최근 5개 유지
- 그 외: 30일 이내만 유지
- 실행 주기: 매주
```

---

## 주의사항

> **보존 정책은 태그를 삭제하지만 실제 이미지 레이어(blob)는 Garbage Collection 실행 전까지 디스크에 남아있습니다.**

```bash
# 보존 정책 실행 후 Garbage Collection으로 실제 디스크 정리
curl -s -X POST "${HARBOR_URL}/api/v2.0/system/gc/schedule" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"schedule": {"type": "Manual"}}'
```
