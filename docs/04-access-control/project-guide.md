# 프로젝트 · 사용자 · RBAC

Harbor에서 이미지를 격리하고 접근 권한을 관리하는 핵심 개념입니다.

---

## 개념 정리

```
Harbor
└── Project (이미지 격리 단위)
    ├── Repository (이미지 이름 그룹)
    │   └── Tag (이미지 버전)
    └── Member (사용자 or Robot Account + Role)
```

| 개념 | 설명 |
|---|---|
| **Project** | 이미지 네임스페이스. 팀/서비스 단위로 분리 |
| **Repository** | 하나의 이미지 이름 (`project/image-name`) |
| **Member** | 프로젝트에 접근할 수 있는 사용자 또는 Robot Account |
| **Role** | 멤버에게 부여하는 권한 수준 |

---

## 프로젝트 접근 유형

| 유형 | 설명 |
|---|---|
| **Public** | 로그인 없이 `docker pull` 가능 |
| **Private** | 인증된 멤버만 접근 가능 |

---

## Role 권한 비교

| 권한 | Project Admin | Maintainer | Developer | Guest | Limited Guest |
|---|:---:|:---:|:---:|:---:|:---:|
| 이미지 Pull | ✅ | ✅ | ✅ | ✅ | ✅ |
| 이미지 Push | ✅ | ✅ | ✅ | ❌ | ❌ |
| 이미지 삭제 | ✅ | ✅ | ❌ | ❌ | ❌ |
| Webhook 관리 | ✅ | ✅ | ❌ | ❌ | ❌ |
| 멤버 관리 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 프로젝트 설정 변경 | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## 프로젝트 생성 (UI)

1. Harbor 웹 UI → **Projects** → **NEW PROJECT**
2. 프로젝트 이름 입력 (예: `backend`, `frontend`, `infra`)
3. Access Level: `Public` 또는 `Private` 선택
4. Storage Quota 설정 (선택, `-1` = 무제한)
5. **OK** 클릭

---

## 프로젝트 생성 (API)

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# 프로젝트 생성
curl -s -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "backend",
    "public": false,
    "metadata": {
      "auto_scan": "true"
    }
  }'

# 프로젝트 목록 조회
curl -s "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[].name'
```

---

## 사용자 생성

### UI에서 생성

1. **Administration** → **Users** → **NEW USER**
2. 사용자 정보 입력:
   - Username: `dev-team`
   - Email: `dev@example.com`
   - Password: `Dev12345!`
   - Real Name: `Dev Team`

### API로 생성

```bash
curl -s -X POST "${HARBOR_URL}/api/v2.0/users" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dev-user",
    "email": "dev@example.com",
    "realname": "Dev User",
    "password": "Dev12345!",
    "comment": "개발팀 계정"
  }'
```

---

## 프로젝트에 멤버 추가

### UI에서 추가

1. 프로젝트 → **Members** → **USER** → **+ USER**
2. 사용자 이름 검색 후 Role 선택

### API로 추가

```bash
# PROJECT_ID 조회
PROJECT_ID=$(curl -s "${HARBOR_URL}/api/v2.0/projects?name=backend" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[0].id')

# 멤버 추가 (role_id: 1=Admin, 2=Developer, 3=Guest, 4=Maintainer, 5=Limited Guest)
curl -s -X POST "${HARBOR_URL}/api/v2.0/projects/${PROJECT_ID}/members" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "role_id": 2,
    "member_user": {
      "username": "dev-user"
    }
  }'
```

---

## 프로젝트별 설정 (중요)

### 자동 스캔 활성화

이미지 Push 시 자동으로 취약점 스캔을 실행합니다.

1. 프로젝트 → **Configuration**
2. **Automatically scan images on push** 체크 활성화

```bash
# API로 설정
curl -s -X PUT "${HARBOR_URL}/api/v2.0/projects/${PROJECT_ID}" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "metadata": {
      "auto_scan": "true"
    }
  }'
```

### CVE 기반 배포 차단 (Prevent vulnerable images)

특정 심각도 이상의 취약점이 있는 이미지 Pull을 차단합니다.

1. 프로젝트 → **Configuration**
2. **Prevent vulnerable images from running** 활성화
3. 차단 기준 심각도 선택 (예: `Critical`)

---

## LDAP / OIDC 연동 (선택)

### OIDC (예: Keycloak)

1. **Administration** → **Configuration** → **Authentication**
2. Auth Mode: `OIDC`
3. 설정값 입력:

```
OIDC Provider Name: Keycloak
OIDC Endpoint: https://keycloak.example.com/realms/myrealm
OIDC Client ID: harbor
OIDC Client Secret: <client-secret>
Group Claim Name: groups
OIDC Scope: openid,profile,email,groups
```

> OIDC 설정 후 최초 로그인 시 Harbor 계정과 OIDC 계정이 연결됩니다.

---

## 실습 시나리오

```
프로젝트 구조 목표:
├── backend   (Private) — backend-team: Developer 권한
├── frontend  (Private) — frontend-team: Developer 권한
└── shared    (Public)  — 공용 base 이미지 배포용
```

```bash
# 1. 프로젝트 3개 생성
for proj in backend frontend; do
  curl -s -X POST "${HARBOR_URL}/api/v2.0/projects" \
    -u "${HARBOR_USER}:${HARBOR_PASS}" \
    -H "Content-Type: application/json" \
    -d "{\"project_name\": \"${proj}\", \"public\": false, \"metadata\": {\"auto_scan\": \"true\"}}"
done

curl -s -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{"project_name": "shared", "public": true}'

# 2. 결과 확인
curl -s "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[].name'
```
