# Harbor Ops

Harbor 운영 보조 자료와 실습 자산을 두는 공간입니다.

| 폴더 | 내용 |
|------|------|
| `install/` | Helm 기반 Harbor 설치 스크립트 |
| `upgrade/` | Harbor Helm 업그레이드 스크립트 |
| `values/` | Helm values 예제 |
| `projects/` | 프로젝트 API payload 예제 |
| `robot-accounts/` | robot account API payload 예제 |
| `replication/` | replication 정책 payload 예제 |

## 주요 파일

| 파일 | 내용 |
|------|------|
| `values/values-minimal.yaml` | 단일 클러스터 기본 설치용 values |
| `values/values-s3-ha.yaml` | EKS + S3 + 외부 DB/Redis HA values |
| `projects/backend-project.json` | backend 프로젝트 생성 payload |
| `robot-accounts/project-ci-pusher.json` | CI push용 project robot account payload |
| `replication/dr-full-replication.json` | DR Harbor 복제 정책 payload |

Harbor 원리를 설명하는 문서는 `docs/`에 두고, 실제 예시 파일과 운영 보조 자료는 `ops/`에 둡니다.
