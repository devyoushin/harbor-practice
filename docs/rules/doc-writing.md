# 문서 작성 원칙 — harbor-practice

## 언어
- 본문은 한국어, 기술 용어(Harbor, Trivy, Cosign, IRSA)는 영어
- 서술체: `~다.`, `~한다.`

## 문서 구조
1. **개요** — 이 기능이 무엇을 해결하는지
2. **Harbor UI 설정** — 단계별 텍스트 설명
3. **API 예시** — curl로 동일 작업 자동화
4. **docker/helm 명령어** — 레지스트리 연동
5. **트러블슈팅** — 자주 겪는 문제

## 코드 블록
- curl 명령어에 한국어 주석
- CLAUDE.md의 `harbor.example.com` 도메인 사용
- 인증 정보는 `<pw>`, `<token>` 플레이스홀더 사용
