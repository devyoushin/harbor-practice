# Helm Chart Registry

Harbor는 컨테이너 이미지뿐만 아니라 Helm Chart를 OCI 형식으로 저장하고 배포할 수 있습니다.

---

## Helm Chart 저장 방식

| 방식 | 설명 | Harbor 버전 |
|---|---|---|
| **OCI 방식** (권장) | OCI Artifact로 저장, `helm push/pull` 사용 | Harbor 2.0+ |
| **Legacy ChartMuseum** | 별도 ChartMuseum 컴포넌트 사용 | Harbor 1.x (Deprecated) |

> Helm 3.8+ 부터 OCI Registry가 GA(정식 출시)되었습니다. OCI 방식을 사용하세요.

---

## 사전 준비

```bash
# Helm 버전 확인 (>= 3.8 필요)
helm version

# OCI 실험적 기능 활성화 (Helm 3.8 미만인 경우)
export HELM_EXPERIMENTAL_OCI=1
```

---

## 1. Harbor에 Helm Chart Push

### Chart 패키징

```bash
# Chart 디렉토리 구조 확인
ls my-chart/
# Chart.yaml  values.yaml  templates/

# Chart 패키징
helm package my-chart/
# Successfully packaged chart and saved it to: my-chart-0.1.0.tgz
```

### Harbor 로그인

```bash
helm registry login harbor.example.com \
  -u admin \
  -p Harbor12345!

# Robot Account 사용 시
helm registry login harbor.example.com \
  -u "robot\$backend+ci-pusher" \
  -p "<robot-secret-token>"
```

### Chart Push

```bash
# helm push <chart-tgz> oci://<harbor-url>/<project>
helm push my-chart-0.1.0.tgz oci://harbor.example.com/backend

# 확인: Harbor UI → Projects → backend → Repositories 에서 확인
```

---

## 2. Helm Chart Pull

```bash
# Chart Pull
helm pull oci://harbor.example.com/backend/my-chart --version 0.1.0

# 특정 디렉토리에 Pull
helm pull oci://harbor.example.com/backend/my-chart \
  --version 0.1.0 \
  --destination ./charts/

# Pull 후 압축 해제
helm pull oci://harbor.example.com/backend/my-chart \
  --version 0.1.0 \
  --untar
```

---

## 3. Helm Chart로 직접 설치/업그레이드

```bash
# 설치
helm install my-release oci://harbor.example.com/backend/my-chart \
  --version 0.1.0 \
  --namespace default

# 커스텀 values로 설치
helm install my-release oci://harbor.example.com/backend/my-chart \
  --version 0.1.0 \
  --values my-values.yaml

# 업그레이드
helm upgrade my-release oci://harbor.example.com/backend/my-chart \
  --version 0.2.0 \
  --values my-values.yaml
```

---

## 4. Chart 정보 조회

```bash
# Chart 메타데이터 조회 (Pull 없이)
helm show chart oci://harbor.example.com/backend/my-chart --version 0.1.0

# Chart values 조회
helm show values oci://harbor.example.com/backend/my-chart --version 0.1.0

# Chart 전체 정보 조회
helm show all oci://harbor.example.com/backend/my-chart --version 0.1.0
```

---

## 5. CI/CD에서 Chart Push 자동화

### GitHub Actions

```yaml
name: Build and Push Helm Chart

on:
  push:
    tags: ['v*']

jobs:
  push-chart:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Install Helm
      uses: azure/setup-helm@v3
      with:
        version: '3.14.0'

    - name: Helm Login to Harbor
      run: |
        helm registry login harbor.example.com \
          -u ${{ secrets.HARBOR_USERNAME }} \
          -p ${{ secrets.HARBOR_TOKEN }}

    - name: Package and Push Chart
      run: |
        VERSION=${GITHUB_REF#refs/tags/v}

        # Chart.yaml의 version 필드를 태그에 맞게 업데이트
        sed -i "s/^version:.*/version: ${VERSION}/" charts/my-chart/Chart.yaml

        helm package charts/my-chart/
        helm push my-chart-${VERSION}.tgz oci://harbor.example.com/backend
```

---

## 6. Harbor API로 Chart 관리

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# 프로젝트 내 Chart 목록 조회
curl -s "${HARBOR_URL}/api/v2.0/projects/backend/repositories" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.[] | select(.artifact_count > 0) | .name'

# 특정 Chart의 버전 목록
curl -s "${HARBOR_URL}/api/v2.0/projects/backend/repositories/my-chart/artifacts" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.[] | {digest: .digest, tags: [.tags[].name], push_time: .push_time}'

# Chart 삭제 (특정 버전)
curl -s -X DELETE \
  "${HARBOR_URL}/api/v2.0/projects/backend/repositories/my-chart/artifacts/0.1.0" \
  -u "${HARBOR_USER}:${HARBOR_PASS}"
```

---

## 7. ArgoCD에서 Harbor OCI Chart 사용

ArgoCD는 OCI Helm Registry를 지원합니다.

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  source:
    repoURL: oci://harbor.example.com/backend
    chart: my-chart
    targetRevision: 0.1.0
    helm:
      values: |
        replicaCount: 2
        image:
          repository: harbor.example.com/backend/my-api
          tag: v1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  project: default
```

```bash
# ArgoCD에 Harbor OCI Registry 자격증명 추가
argocd repo add oci://harbor.example.com/backend \
  --type helm \
  --name harbor-backend \
  --username admin \
  --password Harbor12345!
```

---

## Legacy ChartMuseum 방식 (참고용)

> Harbor 2.x에서는 ChartMuseum이 기본 비활성화되어 있습니다. OCI 방식을 사용하세요.

```bash
# Helm Chart Repository로 추가 (Legacy)
helm repo add harbor-legacy \
  https://harbor.example.com/chartrepo/backend \
  --username admin \
  --password Harbor12345!

helm repo update
helm search repo harbor-legacy/
```
