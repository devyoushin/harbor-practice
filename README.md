# harbor-practice

EKS 환경에서 Harbor Container Registry를 처음부터 운영 수준까지 학습하는 실습 저장소입니다.

---

## 환경 정보

| 항목 | 값 |
|---|---|
| 플랫폼 | AWS EKS |
| Harbor Helm Chart | `bitnami/harbor` (권장 버전: 23.x / Harbor 2.x) |
| 네임스페이스 | `harbor` |
| 스토리지 | S3 (IRSA 인증) + EBS gp3 (PVC) |
| 리전 | `ap-northeast-2` |
| 도메인 | `harbor.example.com` |

---

## 사전 요구사항

```bash
# 필요 도구 확인
kubectl version --client      # >= 1.25
helm version                  # >= 3.10
aws --version                 # AWS CLI v2
docker version                # Docker CLI (이미지 push/pull용)

# EKS 클러스터 접속 확인
kubectl get nodes
```

---

## 빠른 시작 (Quick Start)

```bash
# 1. 네임스페이스 생성
kubectl create namespace harbor

# 2. Helm 저장소 추가
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 3. Harbor 설치
helm install harbor bitnami/harbor \
  --namespace harbor \
  --set externalURL=https://harbor.example.com \
  --set adminPassword=Harbor12345 \
  --version 23.0.0

# 4. 접속 확인
kubectl get pods -n harbor
kubectl get svc -n harbor
```

---

## 학습 경로

### 1단계: 설치
- [Helm으로 Harbor 설치](./install.md)

### 2단계: 핵심 개념
- [프로젝트 · 사용자 · RBAC](./project-guide.md)
- [이미지 Push / Pull](./push-pull-guide.md)
- [Robot Account (CI/CD 연동)](./robot-account-guide.md)

### 3단계: 보안 & 정책
- [이미지 스캐닝 (Trivy)](./scanning-guide.md)
- [Tag 보존 정책 (Retention)](./retention-guide.md)
- [Webhook 설정](./webhook-guide.md)

### 4단계: 고급 기능
- [Proxy Cache (풀스루 캐시)](./proxy-cache-guide.md)
- [Replication 정책](./replication-guide.md)
- [Helm Chart Registry](./helm-chart-guide.md)

### 5단계: 문제 해결
- [트러블슈팅 가이드](./troubleshooting-guide.md)

### 실습
- [End-to-End 실습 (빌드 → 스캔 → 배포)](./e2e-practice.md)

---

## 저장소 구조

```
harbor-practice/
├── README.md
├── CLAUDE.md
├── install.md                 # Helm 설치 가이드
├── project-guide.md           # 프로젝트·사용자·RBAC
├── push-pull-guide.md         # 이미지 Push / Pull
├── robot-account-guide.md     # Robot Account (CI/CD)
├── scanning-guide.md          # Trivy 이미지 스캐닝
├── retention-guide.md         # Tag 보존 정책
├── webhook-guide.md           # Webhook 설정
├── proxy-cache-guide.md       # Proxy Cache
├── replication-guide.md       # Replication 정책
├── helm-chart-guide.md        # Helm Chart Registry
├── troubleshooting-guide.md   # 트러블슈팅
└── e2e-practice.md            # End-to-End 실습
```

---

## 아키텍처 요약

```
Developer / CI
    │
    │  docker push/pull
    ▼
[Nginx (Ingress)]
    │
    ▼
[Harbor Core (API)]  ←──→  [Database (PostgreSQL)]
    │                              │
    │                              ▼
    │                       [Redis (Session/Cache)]
    │
    ├──▶ [Registry (containerd/distribution)]  ──▶  S3 / PVC (이미지 레이어)
    │
    ├──▶ [Trivy (Scan Service)]               ──▶  취약점 DB
    │
    ├──▶ [Jobservice]                          ──▶  비동기 작업 (복제, 스캔)
    │
    └──▶ [Notary (선택)]                       ──▶  이미지 서명
```

| 컴포넌트 | 역할 |
|---|---|
| **Core** | API 서버, 인증·인가, 웹 UI 제공 |
| **Registry** | OCI 컨테이너 이미지 저장소 (distribution 기반) |
| **Jobservice** | 복제·스캐닝 등 비동기 작업 처리 |
| **Trivy** | 이미지 취약점 스캔 엔진 |
| **PostgreSQL** | 메타데이터 (프로젝트, 사용자, 정책) 저장 |
| **Redis** | 세션 캐시, 작업 큐 |
| **Nginx** | 리버스 프록시, TLS 종료 |

---

## 참고 링크

- [Harbor 공식 문서](https://goharbor.io/docs/)
- [bitnami/harbor Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/harbor)
- [Harbor GitHub](https://github.com/goharbor/harbor)
- [Trivy 취약점 DB](https://github.com/aquasecurity/trivy-db)
