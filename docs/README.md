# Harbor Docs

Harbor를 처음 보는 사람이 설치, 프로젝트/RBAC, 이미지 push/pull, 보안 스캔, 보존/복제 정책, 연동, HA 운영, 실습까지 순서대로 따라갈 수 있도록 정리한 문서 디렉터리입니다.

## 빠른 길잡이

| 지금 하고 싶은 일 | 열 문서 |
|------|------|
| Harbor 설치 방식 고르기 | [install/install.md](install/install.md) |
| Harbor 업그레이드하기 | [install/upgrade/README.md](install/upgrade/README.md) |
| 프로젝트와 권한 설계하기 | [access/project-guide.md](access/project-guide.md) |
| Robot Account 만들기 | [access/robot-account-guide.md](access/robot-account-guide.md) |
| 이미지 push/pull 하기 | [artifacts/push-pull-guide.md](artifacts/push-pull-guide.md) |
| Helm Chart를 OCI artifact로 관리하기 | [artifacts/helm-chart-guide.md](artifacts/helm-chart-guide.md) |
| Trivy 스캔과 배포 차단 설정하기 | [security/scanning-guide.md](security/scanning-guide.md) |
| Tag 보존 정책 설정하기 | [policies/retention-guide.md](policies/retention-guide.md) |
| 원격 복제와 DR 구성하기 | [distribution/replication-guide.md](distribution/replication-guide.md) |
| Docker Hub/ECR proxy cache 구성하기 | [distribution/proxy-cache-guide.md](distribution/proxy-cache-guide.md) |
| Webhook 연동하기 | [integrations/webhook-guide.md](integrations/webhook-guide.md) |
| HA 아키텍처와 백업 설계하기 | [architecture/ha-architecture-guide.md](architecture/ha-architecture-guide.md) |
| End-to-End로 검증하기 | [tutorials/e2e-practice.md](tutorials/e2e-practice.md) |
| 장애를 진단하기 | [operations/troubleshooting-guide.md](operations/troubleshooting-guide.md) |

## 추천 읽기 순서

| 순서 | 문서 | 핵심 내용 |
|------|------|------|
| 1 | [install/install.md](install/install.md) | Helm, Docker Compose, systemd 설치 |
| 2 | [access/project-guide.md](access/project-guide.md) | 프로젝트, 사용자, RBAC |
| 3 | [artifacts/push-pull-guide.md](artifacts/push-pull-guide.md) | Docker login, image push/pull, imagePullSecret |
| 4 | [access/robot-account-guide.md](access/robot-account-guide.md) | CI/CD용 Robot Account |
| 5 | [security/scanning-guide.md](security/scanning-guide.md) | Trivy 스캔, 자동 스캔, 취약점 차단 |
| 6 | [policies/retention-guide.md](policies/retention-guide.md) | Tag 보존 정책과 GC |
| 7 | [distribution/replication-guide.md](distribution/replication-guide.md) | Registry 복제와 DR |
| 8 | [distribution/proxy-cache-guide.md](distribution/proxy-cache-guide.md) | 풀스루 캐시 |
| 9 | [integrations/webhook-guide.md](integrations/webhook-guide.md) | Webhook 이벤트와 외부 알림 |
| 10 | [artifacts/helm-chart-guide.md](artifacts/helm-chart-guide.md) | Helm Chart Registry |
| 11 | [architecture/ha-architecture-guide.md](architecture/ha-architecture-guide.md) | HA와 백업 구성 |
| 12 | [tutorials/e2e-practice.md](tutorials/e2e-practice.md) | 빌드 -> 스캔 -> 배포 실습 |
| 13 | [operations/troubleshooting-guide.md](operations/troubleshooting-guide.md) | 증상별 문제 해결 |

## 전체 문서 목록

| 구분 | 문서 |
|------|------|
| 설치 | [install/install.md](install/install.md), [install/upgrade/README.md](install/upgrade/README.md) |
| 접근 제어 | [access/project-guide.md](access/project-guide.md), [access/robot-account-guide.md](access/robot-account-guide.md) |
| Artifact | [artifacts/push-pull-guide.md](artifacts/push-pull-guide.md), [artifacts/helm-chart-guide.md](artifacts/helm-chart-guide.md) |
| 보안 | [security/scanning-guide.md](security/scanning-guide.md) |
| 정책 | [policies/retention-guide.md](policies/retention-guide.md) |
| 배포/캐시 | [distribution/replication-guide.md](distribution/replication-guide.md), [distribution/proxy-cache-guide.md](distribution/proxy-cache-guide.md) |
| 연동 | [integrations/webhook-guide.md](integrations/webhook-guide.md) |
| 아키텍처 | [architecture/ha-architecture-guide.md](architecture/ha-architecture-guide.md) |
| 운영/실습 | [operations/troubleshooting-guide.md](operations/troubleshooting-guide.md), [tutorials/e2e-practice.md](tutorials/e2e-practice.md) |
| 문서 운영 | [rules/README.md](rules/README.md), [templates/README.md](templates/README.md), [agents/README.md](agents/README.md) |
| 실행 자산 | [../ops/README.md](../ops/README.md) |

## 폴더 역할

| 폴더 | 역할 |
|------|------|
| [install/](install/README.md) | 설치와 업그레이드 |
| [access/](access/README.md) | 프로젝트, 사용자, RBAC, Robot Account |
| [artifacts/](artifacts/README.md) | 컨테이너 이미지와 Helm Chart artifact |
| [security/](security/README.md) | Trivy 스캔과 취약점 정책 |
| [policies/](policies/README.md) | Tag 보존 정책 |
| [distribution/](distribution/README.md) | Replication, Proxy Cache |
| [integrations/](integrations/README.md) | Webhook |
| [architecture/](architecture/README.md) | HA 아키텍처와 백업 |
| [operations/](operations/README.md) | 트러블슈팅 |
| [tutorials/](tutorials/README.md) | End-to-End 실습 |

## 관리 원칙

- 설치는 `install/`, 접근 제어는 `access/`, artifact 사용법은 `artifacts/`에 둡니다.
- 스캔/보안은 `security/`, 보존 정책은 `policies/`, 복제/캐시는 `distribution/`에 둡니다.
- 외부 시스템 연동은 `integrations/`, HA 설계는 `architecture/`, 장애 대응은 `operations/`, 직접 따라 하는 검증은 `tutorials/`에 둡니다.
- 실제 적용 가능한 Helm values, API payload, 설치 스크립트는 `ops/`에 둡니다.
