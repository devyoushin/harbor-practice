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
├── agents/                    # doc-writer, registry-designer, security-auditor, troubleshooter
├── templates/                 # service-doc, runbook, incident-report
├── rules/                     # doc-writing, harbor-conventions, security-checklist, monitoring
└── *-guide.md                 # 주제별 가이드 문서
```

---

## 커스텀 슬래시 명령어

| 명령어 | 설명 | 사용 예시 |
|--------|------|---------|
| `/new-doc` | 새 가이드 문서 생성 | `/new-doc ldap-integration` |
| `/new-runbook` | 새 런북 생성 | `/new-runbook Harbor 스토리지 확장` |
| `/review-doc` | 문서 검토 | `/review-doc robot-account-guide.md` |
| `/add-troubleshooting` | 트러블슈팅 케이스 추가 | `/add-troubleshooting docker push 인증 실패` |
| `/search-kb` | 지식베이스 검색 | `/search-kb 이미지 취약점 스캔` |

---

## 가이드 문서 목록

| 문서 | 주제 |
|------|------|
| `install.md` | Harbor 설치 (Helm + EKS) |
| `project-guide.md` | 프로젝트 관리 |
| `push-pull-guide.md` | 이미지 Push/Pull |
| `replication-guide.md` | 원격 복제 정책 |
| `scanning-guide.md` | 취약점 스캔 (Trivy) |
| `robot-account-guide.md` | 로봇 계정 관리 |
| `webhook-guide.md` | Webhook 설정 |
| `proxy-cache-guide.md` | 프록시 캐시 |
| `retention-guide.md` | 이미지 보존 정책 |
| `helm-chart-guide.md` | Helm 차트 레지스트리 |
| `troubleshooting-guide.md` | 트러블슈팅 |
| `e2e-practice.md` | 엔드투엔드 실습 |

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
