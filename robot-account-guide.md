# Robot Account (CI/CD 연동)

Robot Account는 사람 계정 대신 자동화 시스템(CI/CD, 스크립트)이 Harbor에 접근할 때 사용하는 전용 서비스 계정입니다.

---

## Robot Account vs 일반 사용자

| 구분 | 일반 사용자 | Robot Account |
|---|---|---|
| 목적 | 사람이 직접 사용 | 자동화 시스템용 |
| 로그인 방식 | username + password | username + token |
| 토큰 만료 | 없음 (비밀번호) | 설정 가능 (일 단위) |
| 권한 범위 | 프로젝트별 Role | 특정 작업만 허용 가능 |
| 권장 용도 | UI 접근, 관리 작업 | CI/CD, 스크립트 |

---

## Robot Account 유형

| 유형 | 범위 | 용도 |
|---|---|---|
| **System Robot** | 전체 Harbor | 여러 프로젝트에 걸친 자동화 |
| **Project Robot** | 특정 프로젝트 | 프로젝트 단위 CI/CD |

---

## Project Robot Account 생성

### UI에서 생성

1. **Projects** → 해당 프로젝트 → **Robot Accounts** → **NEW ROBOT ACCOUNT**
2. 설정:
   - Name: `ci-pusher`
   - Expiration Time: `30` (일) 또는 `Never expire`
   - Permissions:
     - ✅ Push Repository
     - ✅ Pull Repository
     - ✅ Create Tag
     - ✅ Delete Tag (선택)
3. **ADD** 클릭 → 토큰을 반드시 복사해서 저장 (재확인 불가)

### API로 생성

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# Project Robot Account 생성
curl -s -X POST "${HARBOR_URL}/api/v2.0/projects/backend/robots" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ci-pusher",
    "description": "GitHub Actions CI/CD용 Robot Account",
    "duration": 30,
    "level": "project",
    "permissions": [
      {
        "kind": "project",
        "namespace": "backend",
        "access": [
          {"resource": "repository", "action": "push"},
          {"resource": "repository", "action": "pull"},
          {"resource": "tag", "action": "create"},
          {"resource": "artifact", "action": "delete"}
        ]
      }
    ]
  }'
```

응답 예시:
```json
{
  "id": 5,
  "name": "robot$backend+ci-pusher",
  "secret": "eyJhbGciOiJSUzI1NiIsIn...",
  "creation_time": "2026-04-14T00:00:00Z",
  "expiration_time": "2026-05-14T00:00:00Z"
}
```

> `secret` 값은 이 응답에서만 확인 가능합니다. 반드시 저장하세요.

---

## System Robot Account 생성

```bash
# 여러 프로젝트에 걸친 System Robot Account
curl -s -X POST "${HARBOR_URL}/api/v2.0/robots" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "global-scanner",
    "description": "전체 프로젝트 스캔용",
    "duration": -1,
    "level": "system",
    "permissions": [
      {
        "kind": "project",
        "namespace": "*",
        "access": [
          {"resource": "repository", "action": "pull"},
          {"resource": "scan", "action": "create"}
        ]
      }
    ]
  }'
```

---

## Robot Account로 Docker 로그인

```bash
# Robot Account 이름 형식: robot$<project>+<name>
docker login harbor.example.com \
  -u "robot\$backend+ci-pusher" \
  -p "<robot-secret-token>"

# Push
docker push harbor.example.com/backend/my-api:v1.0.0
```

> Shell에서 `$` 문자는 이스케이프(`\$`)가 필요합니다.

---

## GitHub Actions에서 사용

```yaml
# .github/workflows/build-push.yml
name: Build and Push to Harbor

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Log in to Harbor
      uses: docker/login-action@v3
      with:
        registry: harbor.example.com
        username: ${{ secrets.HARBOR_USERNAME }}   # robot$backend+ci-pusher
        password: ${{ secrets.HARBOR_TOKEN }}      # robot account secret

    - name: Build and push
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: |
          harbor.example.com/backend/my-api:${{ github.sha }}
          harbor.example.com/backend/my-api:latest
```

GitHub Secrets 설정:
- `HARBOR_USERNAME`: `robot$backend+ci-pusher`
- `HARBOR_TOKEN`: Robot Account 생성 시 발급된 secret

---

## GitLab CI에서 사용

```yaml
# .gitlab-ci.yml
variables:
  HARBOR_REGISTRY: harbor.example.com
  HARBOR_PROJECT: backend
  IMAGE_NAME: my-api

build-and-push:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - docker login $HARBOR_REGISTRY -u $HARBOR_USER -p $HARBOR_TOKEN
  script:
    - docker build -t $HARBOR_REGISTRY/$HARBOR_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $HARBOR_REGISTRY/$HARBOR_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHA
  variables:
    HARBOR_USER: $HARBOR_ROBOT_USER     # GitLab CI/CD Variables에서 설정
    HARBOR_TOKEN: $HARBOR_ROBOT_TOKEN   # GitLab CI/CD Variables에서 설정
```

---

## Robot Account 토큰 갱신

토큰이 만료되거나 보안 사고 발생 시 토큰을 재발급합니다.

```bash
# 토큰 재발급 (Robot Account ID 필요)
ROBOT_ID=5

curl -s -X PATCH "${HARBOR_URL}/api/v2.0/projects/backend/robots/${ROBOT_ID}" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"secret": ""}'
# secret을 빈 문자열로 보내면 새 토큰이 자동 생성됨
```

또는 UI: **Projects** → **Robot Accounts** → 해당 Robot → **Reset Secret**

---

## Robot Account 목록 조회 및 삭제

```bash
# 프로젝트 Robot Account 목록
curl -s "${HARBOR_URL}/api/v2.0/projects/backend/robots" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[] | {id: .id, name: .name, disabled: .disabled}'

# Robot Account 비활성화
curl -s -X PUT "${HARBOR_URL}/api/v2.0/projects/backend/robots/${ROBOT_ID}" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"disabled": true}'

# Robot Account 삭제
curl -s -X DELETE "${HARBOR_URL}/api/v2.0/projects/backend/robots/${ROBOT_ID}" \
  -u "${HARBOR_USER}:${HARBOR_PASS}"
```
