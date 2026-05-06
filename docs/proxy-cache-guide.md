# Proxy Cache (풀스루 캐시)

Harbor의 Proxy Cache 기능을 사용하면 Docker Hub, ECR, GCR 등 외부 Registry의 이미지를 Harbor를 통해 Pull하고 자동으로 캐싱합니다.

---

## Proxy Cache란?

```
기존 방식:
  Pod → 인터넷 → Docker Hub

Proxy Cache 방식:
  Pod → Harbor → (캐시 없으면) 인터넷 → Docker Hub
                  (캐시 있으면) Harbor 캐시에서 응답
```

### 장점

- **Rate Limit 회피**: Docker Hub의 익명 pull 제한(100회/6시간) 우회
- **속도 향상**: 동일 이미지를 여러 노드에서 pull 시 Harbor 내부 네트워크 속도
- **가용성**: 외부 Registry 장애 시에도 캐시된 이미지 사용 가능
- **감사**: 어떤 이미지를 사용하는지 중앙에서 관리

---

## 지원하는 외부 Registry

| Registry | 유형 |
|---|---|
| Docker Hub | `Docker Hub` |
| AWS ECR | `Aws-ECR` |
| GCP Artifact Registry | `Google GCR` |
| Azure ACR | `Azure ACR` |
| GitHub Container Registry | `Github GHCR` |
| JFrog Artifactory | `JFrog Artifactory` |
| Quay | `Quay` |

---

## 1. Proxy Cache Registry 등록

### UI에서 등록

1. **Administration** → **Registries** → **NEW ENDPOINT**
2. 설정:

| 항목 | 예시 |
|---|---|
| Provider | `Docker Hub` |
| Name | `dockerhub-proxy` |
| Endpoint URL | `https://hub.docker.com` |
| Access ID | Docker Hub 계정 (선택, Rate Limit 해제용) |
| Access Secret | Docker Hub 비밀번호 또는 PAT |
| Verify Remote Cert | ✅ |

3. **TEST CONNECTION** → **OK**

### API로 등록

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# Docker Hub Endpoint 등록
curl -s -X POST "${HARBOR_URL}/api/v2.0/registries" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dockerhub-proxy",
    "type": "docker-hub",
    "url": "https://hub.docker.com",
    "credential": {
      "access_key": "dockerhub-username",
      "access_secret": "dockerhub-token"
    },
    "insecure": false
  }'

# ECR Endpoint 등록
curl -s -X POST "${HARBOR_URL}/api/v2.0/registries" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ecr-proxy",
    "type": "aws-ecr",
    "url": "https://<account-id>.dkr.ecr.ap-northeast-2.amazonaws.com",
    "credential": {
      "access_key": "AWS_ACCESS_KEY_ID",
      "access_secret": "AWS_SECRET_ACCESS_KEY"
    }
  }'
```

---

## 2. Proxy Cache 프로젝트 생성

Proxy Cache는 일반 프로젝트와 별도로 **Proxy Cache 전용 프로젝트**를 만들어야 합니다.

### UI에서 생성

1. **Projects** → **NEW PROJECT**
2. **Proxy Cache** 토글 활성화
3. Registry 선택: `dockerhub-proxy`
4. 프로젝트 이름: `dockerhub` (이름을 Registry 이름과 맞추면 관리 편의성 증가)

### API로 생성

```bash
# Endpoint ID 확인
REGISTRY_ID=$(curl -s "${HARBOR_URL}/api/v2.0/registries?name=dockerhub-proxy" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[0].id')

# Proxy Cache 프로젝트 생성
curl -s -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_name\": \"dockerhub\",
    \"public\": true,
    \"registry_id\": ${REGISTRY_ID}
  }"
```

---

## 3. Proxy Cache 사용

프로젝트 생성 후 Harbor를 통해 Docker Hub 이미지를 Pull합니다.

```bash
# 기존: Docker Hub에서 직접 pull
docker pull nginx:alpine

# Proxy Cache 사용: Harbor를 통해 pull
docker pull harbor.example.com/dockerhub/library/nginx:alpine
# 공식 이미지는 'library/' 네임스페이스 사용

# 일반 사용자 이미지
docker pull harbor.example.com/dockerhub/bitnami/redis:7.0
```

### 최초 Pull 시 동작

```
harbor.example.com/dockerhub/library/nginx:alpine 요청
         │
         ▼ (캐시 없음)
Harbor → Docker Hub에서 nginx:alpine 다운로드
         │
         ▼
Harbor Registry에 캐시 저장
         │
         ▼
클라이언트에 이미지 전달

두 번째 Pull 시:
harbor.example.com/dockerhub/library/nginx:alpine 요청
         │
         ▼ (캐시 있음)
Harbor Registry에서 즉시 반환
```

---

## Kubernetes에서 Proxy Cache 사용

### 모든 파드에 Proxy Cache 적용

노드의 Docker/containerd 설정에서 Harbor를 미러로 등록합니다.

```toml
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://harbor.example.com/v2/dockerhub"]
```

```bash
# containerd 재시작
sudo systemctl restart containerd
```

> EKS의 경우 Launch Template의 UserData로 노드 부팅 시 설정을 자동 적용할 수 있습니다.

---

## Proxy Cache 만료 정책

캐시된 이미지에 Tag 보존 정책을 적용해 오래된 캐시를 자동으로 정리합니다.

```bash
# Proxy Cache 프로젝트에도 일반 보존 정책과 동일하게 적용
# (retention-guide.md 참고)
```

---

## 주의사항

- Proxy Cache 프로젝트의 이미지는 **Pull 전용**입니다 (직접 Push 불가).
- `latest` 태그의 경우 Harbor가 캐시를 갱신하는 주기가 있습니다 (기본 24시간).
  최신 이미지가 필요한 경우 Harbor UI에서 캐시를 수동으로 무효화하거나 특정 다이제스트로 Pull하세요.
- Docker Hub Authenticated Pull을 사용해 Rate Limit을 올리려면 반드시 Docker Hub 계정을 Endpoint에 등록하세요.
