# harbor-practice

EKS 환경에서 Harbor Container Registry를 설치하고 프로젝트/RBAC, 이미지 push/pull, 취약점 스캔, 복제, 프록시 캐시, HA 운영까지 학습하는 실습 저장소입니다.

## 먼저 볼 문서

| 목적 | 문서 |
|------|------|
| 전체 문서 목차 보기 | [docs/README.md](docs/README.md) |
| Harbor 설치하기 | [docs/install/install.md](docs/install/install.md) |
| 프로젝트와 권한 이해하기 | [docs/access/project-guide.md](docs/access/project-guide.md) |
| 이미지 Push/Pull 실습하기 | [docs/artifacts/push-pull-guide.md](docs/artifacts/push-pull-guide.md) |
| Robot Account로 CI/CD 연동하기 | [docs/access/robot-account-guide.md](docs/access/robot-account-guide.md) |
| 취약점 스캔 설정하기 | [docs/security/scanning-guide.md](docs/security/scanning-guide.md) |
| End-to-End 실습하기 | [docs/tutorials/e2e-practice.md](docs/tutorials/e2e-practice.md) |
| 운영 자산 확인하기 | [ops/README.md](ops/README.md) |

## 추천 학습 순서

1. [Harbor 설치](docs/install/install.md)
2. [프로젝트/사용자/RBAC](docs/access/project-guide.md)
3. [이미지 Push/Pull](docs/artifacts/push-pull-guide.md)
4. [Robot Account](docs/access/robot-account-guide.md)
5. [이미지 스캐닝](docs/security/scanning-guide.md)
6. [Tag 보존 정책](docs/policies/retention-guide.md)
7. [Replication](docs/distribution/replication-guide.md), [Proxy Cache](docs/distribution/proxy-cache-guide.md)
8. [Webhook](docs/integrations/webhook-guide.md), [Helm Chart Registry](docs/artifacts/helm-chart-guide.md)
9. [HA 아키텍처](docs/architecture/ha-architecture-guide.md)
10. [End-to-End 실습](docs/tutorials/e2e-practice.md)
11. [트러블슈팅](docs/operations/troubleshooting-guide.md)

## 디렉터리 구조

```text
harbor-practice/
├── README.md
├── CLAUDE.md          # AI 작업 지침
├── docs/
│   ├── README.md     # 문서 전체 목차
│   ├── install/      # 설치와 업그레이드
│   ├── access/       # 프로젝트, 사용자, RBAC, Robot Account
│   ├── artifacts/    # 이미지 Push/Pull, Helm Chart Registry
│   ├── security/     # Trivy 취약점 스캔
│   ├── policies/     # 보존 정책
│   ├── distribution/ # Replication, Proxy Cache
│   ├── integrations/ # Webhook
│   ├── architecture/ # HA 아키텍처와 백업
│   ├── operations/   # 트러블슈팅
│   ├── tutorials/    # End-to-End 실습
│   ├── agents/       # AI 역할별 작업 지침
│   ├── rules/        # 문서/운영 규칙
│   └── templates/    # 서비스 문서, 런북, 장애 보고서 템플릿
└── ops/
    ├── README.md
    ├── install/
    ├── upgrade/
    ├── values/
    ├── projects/
    ├── robot-accounts/
    └── replication/
```

## 환경 정보

| 항목 | 값 |
|---|---|
| 플랫폼 | AWS EKS |
| Harbor Helm Chart | `bitnami/harbor` |
| 네임스페이스 | `harbor` |
| 스토리지 | S3 (IRSA 인증) + EBS gp3 (PVC) |
| 리전 | `ap-northeast-2` |
| 도메인 | `harbor.example.com` |
