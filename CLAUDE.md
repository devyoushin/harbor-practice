# harbor-practice — 프로젝트 가이드

## 프로젝트 설정
- 환경: EKS
- Harbor 버전: 2.x (bitnami/harbor Helm chart)
- 네임스페이스: harbor
- 스토리지: S3 (IRSA 인증) + EBS (PVC)
- 도메인: harbor.example.com
- 앱 이름: harbor

---

## 디렉토리 구조

```
harbor-practice/
├── CLAUDE.md                  # 이 파일 (자동 로드)
├── .claude/
│   ├── settings.json
│   └── commands/              # /new-doc, /new-runbook, /review-doc, /add-troubleshooting, /search-kb
├── docs/
│   ├── install/               # 설치와 업그레이드
│   ├── access/                # 프로젝트, 사용자, RBAC, Robot Account
│   ├── artifacts/             # 이미지 Push/Pull, Helm Chart Registry
│   ├── security/              # Trivy 취약점 스캔
│   ├── policies/              # Tag 보존 정책
│   ├── distribution/          # Replication, Proxy Cache
│   ├── integrations/          # Webhook
│   ├── architecture/          # HA 아키텍처와 백업
│   ├── operations/            # 트러블슈팅
│   ├── tutorials/             # End-to-End 실습
│   ├── agents/                # doc-writer, registry-designer, security-auditor, troubleshooter
│   ├── templates/             # service-doc, runbook, incident-report
│   └── rules/                 # doc-writing, harbor-conventions, security-checklist, monitoring
```

---

## 커스텀 슬래시 명령어

| 명령어 | 설명 | 사용 예시 |
|--------|------|---------|
| `/new-doc` | 새 가이드 문서 생성 | `/new-doc ldap-integration` |
| `/new-runbook` | 새 런북 생성 | `/new-runbook Harbor 스토리지 확장` |
| `/review-doc` | 문서 검토 | `/review-doc docs/04-access-control/robot-account-guide.md` |
| `/add-troubleshooting` | 트러블슈팅 케이스 추가 | `/add-troubleshooting docker push 인증 실패` |
| `/search-kb` | 지식베이스 검색 | `/search-kb 이미지 취약점 스캔` |

---

## 가이드 문서 목록

| 문서 | 주제 |
|------|------|
| `docs/01-installation/install.md` | Harbor 설치 (Helm + EKS) |
| `docs/04-access-control/project-guide.md` | 프로젝트 관리 |
| `docs/03-artifacts/push-pull-guide.md` | 이미지 Push/Pull |
| `docs/07-distribution/replication-guide.md` | 원격 복제 정책 |
| `docs/06-security/scanning-guide.md` | 취약점 스캔 (Trivy) |
| `docs/04-access-control/robot-account-guide.md` | 로봇 계정 관리 |
| `docs/08-integrations/webhook-guide.md` | Webhook 설정 |
| `docs/07-distribution/proxy-cache-guide.md` | 프록시 캐시 |
| `docs/05-policies/retention-guide.md` | 이미지 보존 정책 |
| `docs/03-artifacts/helm-chart-guide.md` | Helm 차트 레지스트리 |
| `docs/09-operations/troubleshooting-guide.md` | 트러블슈팅 |
| `docs/10-tutorials/e2e-practice.md` | 엔드투엔드 실습 |
| `docs/02-architecture/ha-architecture-guide.md` | 대규모 HA 아키텍처 및 백업 구성 |

---

## 핵심 명령어

```bash
# Harbor 헬스 체크
curl -u admin:<pw> https://harbor.example.com/api/v2.0/health

# docker 로그인
docker login harbor.example.com -u robot\$<name> -p <token>

# 이미지 태그 및 푸시
docker tag <image> harbor.example.com/<project>/<repo>:<tag>
docker push harbor.example.com/<project>/<repo>:<tag>

# Harbor 컴포넌트 상태
kubectl get pods -n harbor
```
