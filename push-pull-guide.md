# 이미지 Push / Pull

Harbor에 컨테이너 이미지를 업로드하고 내려받는 방법을 다룹니다.

---

## 이미지 주소 형식

```
harbor.example.com/<project>/<repository>:<tag>

예시:
harbor.example.com/backend/my-api:v1.0.0
harbor.example.com/frontend/web-app:latest
harbor.example.com/shared/base-image:alpine3.18
```

---

## Docker Login

```bash
docker login harbor.example.com
# Username: admin (또는 일반 사용자)
# Password: Harbor12345!
```

### 자체 서명 인증서 사용 시

```bash
# 방법 1: Docker daemon에 insecure-registries 추가
# /etc/docker/daemon.json
{
  "insecure-registries": ["harbor.example.com"]
}
sudo systemctl restart docker

# 방법 2: Harbor CA 인증서를 시스템에 등록
# Harbor UI → Administration → Configuration → System Settings → Download Root Cert
sudo cp harbor.crt /usr/local/share/ca-certificates/harbor.crt
sudo update-ca-certificates
sudo systemctl restart docker
```

---

## 이미지 Push

### 1. 이미지 빌드

```bash
# Dockerfile이 있는 디렉토리에서
docker build -t my-api:v1.0.0 .
```

### 2. 태그 지정

```bash
# docker tag <로컬이미지>:<태그> <harbor주소>/<프로젝트>/<이름>:<태그>
docker tag my-api:v1.0.0 harbor.example.com/backend/my-api:v1.0.0

# latest 태그도 함께 푸시하는 경우
docker tag my-api:v1.0.0 harbor.example.com/backend/my-api:latest
```

### 3. Push

```bash
docker push harbor.example.com/backend/my-api:v1.0.0
docker push harbor.example.com/backend/my-api:latest
```

### 4. 확인

```bash
# Harbor UI → Projects → backend → Repositories 에서 확인

# 또는 API로 확인
curl -s "https://harbor.example.com/api/v2.0/projects/backend/repositories" \
  -u "admin:Harbor12345!" | jq '.[].name'
```

---

## 이미지 Pull

```bash
# Public 프로젝트 (로그인 불필요)
docker pull harbor.example.com/shared/base-image:alpine3.18

# Private 프로젝트 (로그인 필요)
docker login harbor.example.com
docker pull harbor.example.com/backend/my-api:v1.0.0
```

---

## Kubernetes에서 Harbor 이미지 사용

### imagePullSecret 생성

```bash
kubectl create secret docker-registry harbor-credentials \
  --docker-server=harbor.example.com \
  --docker-username=admin \
  --docker-password=Harbor12345! \
  --docker-email=admin@example.com \
  --namespace default
```

### Deployment에서 사용

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-api
  template:
    metadata:
      labels:
        app: my-api
    spec:
      containers:
      - name: my-api
        image: harbor.example.com/backend/my-api:v1.0.0
        ports:
        - containerPort: 8080
      imagePullSecrets:
      - name: harbor-credentials
```

### ServiceAccount에 imagePullSecret 연결 (네임스페이스 전체 적용)

```bash
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "harbor-credentials"}]}' \
  -n default
```

> 이후 해당 네임스페이스의 모든 파드가 Harbor에서 이미지를 자동으로 pull할 수 있습니다.

---

## Robot Account를 사용한 CI/CD Push

> CI/CD 파이프라인에서는 개인 계정 대신 Robot Account를 사용하세요.
> 자세한 내용은 [robot-account-guide.md](./robot-account-guide.md)를 참고하세요.

```bash
# Robot Account 토큰으로 로그인
docker login harbor.example.com \
  -u "robot$backend+ci-pusher" \
  -p "<robot-account-token>"

# Push
docker push harbor.example.com/backend/my-api:v1.0.0
```

---

## 태그 삭제

```bash
# UI: Projects → backend → Repositories → my-api → 태그 선택 → DELETE

# API
curl -s -X DELETE \
  "https://harbor.example.com/api/v2.0/projects/backend/repositories/my-api/artifacts/v1.0.0" \
  -u "admin:Harbor12345!"
```

> **주의**: Harbor는 기본적으로 이미지 레이어(blob)를 즉시 삭제하지 않습니다.
> 실제 디스크 반환은 **Garbage Collection** 실행 후 이루어집니다.

---

## Garbage Collection 실행

```bash
# UI: Administration → Garbage Collection → GC Now

# API
curl -s -X POST \
  "https://harbor.example.com/api/v2.0/system/gc/schedule" \
  -u "admin:Harbor12345!" \
  -H "Content-Type: application/json" \
  -d '{
    "schedule": {
      "type": "Manual"
    }
  }'
```

---

## OCI Artifact 지원

Harbor는 컨테이너 이미지 외에도 OCI Artifact를 저장할 수 있습니다.

```bash
# Helm Chart를 OCI 형식으로 push
helm push my-chart-0.1.0.tgz oci://harbor.example.com/charts

# Cosign으로 이미지 서명 저장
cosign sign harbor.example.com/backend/my-api:v1.0.0

# SBOM 저장
syft harbor.example.com/backend/my-api:v1.0.0 -o spdx-json > sbom.json
oras push harbor.example.com/backend/my-api:sbom sbom.json:application/spdx+json
```
