# Harbor 설치 (Helm)

EKS 환경에서 `bitnami/harbor` Helm Chart로 Harbor를 설치합니다.

---

## 사전 조건 확인

```bash
# kubectl 연결 확인
kubectl get nodes

# Helm 버전 확인 (>= 3.10 권장)
helm version

# AWS CLI 설정 확인
aws sts get-caller-identity

# EKS OIDC Provider 활성화 여부 확인 (IRSA 사용 시 필수)
aws eks describe-cluster \
  --name <CLUSTER_NAME> \
  --query "cluster.identity.oidc.issuer" \
  --output text
```

---

## 1. 네임스페이스 생성

```bash
kubectl create namespace harbor
```

---

## 2. Helm 저장소 추가

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 사용 가능한 버전 확인
helm search repo bitnami/harbor --versions | head -10
```

---

## 3. TLS 인증서 준비

Harbor는 HTTPS를 강력히 권장합니다. cert-manager를 사용하거나 ACM을 활용합니다.

### 옵션 A: cert-manager (Let's Encrypt)

```bash
# cert-manager 설치
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# ClusterIssuer 생성
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 옵션 B: 자체 서명 인증서 (개발/테스트용)

```bash
# 자체 서명 인증서 생성
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=harbor.example.com/O=harbor"

# Secret으로 등록
kubectl create secret tls harbor-tls \
  --cert=tls.crt --key=tls.key \
  -n harbor
```

---

## 4. Ingress Controller 확인

```bash
# ingress-nginx 설치 여부 확인
kubectl get pods -n ingress-nginx

# 없으면 설치
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

---

## 5. values.yaml 준비

```bash
# 기본값 추출
helm show values bitnami/harbor > harbor-values.yaml
```

최소 운영 `values.yaml` 예시:

```yaml
# harbor-values.yaml

externalURL: https://harbor.example.com

# 관리자 비밀번호 (반드시 변경)
adminPassword: "Harbor12345!"

# Ingress 설정
ingress:
  core:
    ingressClassName: nginx
    hostname: harbor.example.com
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    tls: true

# 이미지 스토리지: S3 사용 시
persistence:
  enabled: true
  resourcePolicy: keep
  persistentVolumeClaim:
    registry:
      storageClass: gp3
      size: 100Gi
    jobservice:
      storageClass: gp3
      size: 10Gi
    database:
      storageClass: gp3
      size: 20Gi
    redis:
      storageClass: gp3
      size: 5Gi
    trivy:
      storageClass: gp3
      size: 10Gi

# Trivy 스캐너 활성화
trivy:
  enabled: true

# PostgreSQL 설정
postgresql:
  auth:
    password: "Harbor-PG-Pass"
    postgresPassword: "Harbor-PG-Admin-Pass"

# Redis 설정
redis:
  auth:
    password: "Harbor-Redis-Pass"
```

> **S3를 Registry 스토리지로 사용할 경우** `persistence.imageChartStorage` 섹션을 참고하세요.
> IRSA 설정이 필요합니다.

---

## 6. Harbor 설치

```bash
HARBOR_CHART_VERSION="23.0.0"

helm install harbor bitnami/harbor \
  --namespace harbor \
  --values harbor-values.yaml \
  --version ${HARBOR_CHART_VERSION} \
  --timeout 15m \
  --wait
```

---

## 7. 설치 확인

```bash
# 파드 상태 확인
kubectl get pods -n harbor

# 서비스 및 Ingress 확인
kubectl get svc,ingress -n harbor
```

정상 설치 시 아래 파드가 모두 `Running` 상태여야 합니다:

| 컴포넌트 | 설명 |
|---|---|
| `harbor-core` | API 서버 + 웹 UI |
| `harbor-registry` | 이미지 저장소 |
| `harbor-jobservice` | 비동기 작업 처리 |
| `harbor-trivy` | 이미지 스캐너 |
| `harbor-nginx` | 내부 리버스 프록시 |
| `harbor-postgresql` | 메타데이터 DB |
| `harbor-redis-master` | 캐시 & 큐 |

```bash
# 빠른 상태 확인
kubectl get pods -n harbor \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount'
```

---

## 8. 첫 접속

```bash
# Ingress IP 확인
kubectl get ingress -n harbor

# 또는 포트 포워드로 직접 접근 (테스트용)
kubectl port-forward svc/harbor 8443:443 -n harbor
```

브라우저에서 `https://harbor.example.com` 접속:
- 계정: `admin`
- 비밀번호: values.yaml의 `adminPassword`

---

## 업그레이드

```bash
# 업그레이드 전 현재 values 확인
helm get values harbor -n harbor

# 업그레이드
helm upgrade harbor bitnami/harbor \
  --namespace harbor \
  --values harbor-values.yaml \
  --version 23.1.0 \
  --timeout 15m

# 히스토리 확인
helm history harbor -n harbor
```

> **주의**: 메이저 버전 업그레이드 시 DB 마이그레이션이 자동 실행됩니다.
> 업그레이드 전 반드시 PostgreSQL 백업을 수행하세요.

---

## 롤백

```bash
helm rollback harbor 1 -n harbor
```

---

## 삭제

```bash
helm uninstall harbor -n harbor

# PVC 삭제 (데이터 영구 삭제)
kubectl delete pvc -n harbor -l app.kubernetes.io/instance=harbor

# 네임스페이스 삭제
kubectl delete namespace harbor
```

> **주의**: PVC 삭제 시 이미지 데이터가 모두 사라집니다.

---

## 설치 시 자주 발생하는 문제

| 증상 | 원인 | 해결 방법 |
|---|---|---|
| Core `CrashLoopBackOff` | DB 연결 실패 | PostgreSQL 파드 상태 및 비밀번호 확인 |
| Registry `Pending` | PVC 생성 실패 | StorageClass `gp3` 존재 여부 확인 |
| `Error: INSTALLATION FAILED: timed out` | 리소스 부족 | 노드 용량 확인, `--timeout` 연장 |
| Trivy 스캔 실패 | 취약점 DB 다운로드 실패 | 인터넷 접속 여부, Trivy PVC 용량 확인 |
| 브라우저 인증서 경고 | 자체 서명 인증서 | cert-manager로 Let's Encrypt 인증서 발급 |
| `docker login` 실패 | HTTPS 인증서 문제 | Docker daemon의 `insecure-registries` 설정 또는 CA 등록 |
