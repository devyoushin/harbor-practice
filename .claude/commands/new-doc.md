새 Harbor 가이드 문서를 생성합니다.

**사용법**: `/new-doc <주제명>`

**예시**: `/new-doc ldap-integration`

주제 분류:
- 레지스트리 관리: project, push-pull, replication
- 보안: scanning, robot-account, webhook, verify-image
- 운영: retention, proxy-cache, helm-chart
- 설치: install, upgrade

`<주제명>-guide.md` 생성 시 포함 내용:
- CLAUDE.md 환경 설정 반영 (EKS, Harbor 버전)
- Harbor UI 또는 API 조작 방법
- docker/helm 명령어 예시
- 트러블슈팅 섹션
