# Harbor Ops

Harbor를 실제로 설치하거나 실습할 때 사용하는 Helm values, 설치 스크립트, API payload를 두는 공간입니다. 개념 설명은 `docs/`에, 적용 가능한 실행 자산은 `ops/`에 둡니다.

## 폴더 구조

| 폴더 | 내용 |
|------|------|
| `install/` | Helm, Docker Compose, systemd 설치 예시 |
| `upgrade/` | Harbor Helm 업그레이드 스크립트 |
| `values/` | Helm values 예제 |
| `projects/` | 프로젝트 API payload 예제 |
| `robot-accounts/` | Robot Account API payload 예제 |
| `replication/` | Replication 정책 payload 예제 |

## 주요 파일

| 파일 | 내용 |
|------|------|
| `values/values-minimal.yaml` | 단일 클러스터 기본 설치용 values |
| `values/values-s3-ha.yaml` | EKS + S3 + 외부 DB/Redis HA values |
| `projects/backend-project.json` | backend 프로젝트 생성 payload |
| `robot-accounts/project-ci-pusher.json` | CI push용 project robot account payload |
| `replication/dr-full-replication.json` | DR Harbor 복제 정책 payload |
| `install/install-harbor-docker.sh` | Harbor release package 설치 및 Compose 초기화 |
| `install/harbor.service` | Docker Compose Harbor 스택 systemd 유닛 |

## 관련 문서

| 작업 | 문서 |
|------|------|
| Harbor 설치 | [../docs/install/install.md](../docs/install/install.md) |
| Helm 업그레이드 | [../docs/install/upgrade/README.md](../docs/install/upgrade/README.md) |
| 프로젝트 생성 | [../docs/access/project-guide.md](../docs/access/project-guide.md) |
| Robot Account 생성 | [../docs/access/robot-account-guide.md](../docs/access/robot-account-guide.md) |
| 복제 정책 | [../docs/distribution/replication-guide.md](../docs/distribution/replication-guide.md) |
| HA values | [../docs/architecture/ha-architecture-guide.md](../docs/architecture/ha-architecture-guide.md) |
| 트러블슈팅 | [../docs/operations/troubleshooting-guide.md](../docs/operations/troubleshooting-guide.md) |

## 관리 원칙

- 재사용 가능한 values, 설치 스크립트, API payload는 이 디렉터리에 둡니다.
- 문서 본문에는 핵심 스니펫만 넣고, 전체 적용 파일은 `ops/`를 기준으로 관리합니다.
- 비밀번호, 토큰, 실제 도메인, 실제 클라우드 계정 정보는 커밋하지 않습니다.
