# AGENTS.md — harbor-practice Codex 작업 지침

이 저장소는 Harbor registry 운영 지식 베이스입니다. Codex 작업 시 `CLAUDE.md`와 `docs/rules/`의 규칙을 동일하게 따릅니다.

## 공통 원칙

- Harbor 설치, 프로젝트, 스캔, 복제, HA 설명은 `docs/`에 둡니다.
- Helm values, API payload, 설치/업그레이드 스크립트는 `ops/`에 둡니다.
- 업그레이드 문서와 스크립트는 DB 백업, rollback, chart values 보존을 반드시 고려합니다.
- 보안 관련 내용은 robot account, project 권한, vulnerability scan, replication 권한을 명확히 분리합니다.

## Claude와의 싱크

- `CLAUDE.md`는 Claude용 지침입니다.
- `AGENTS.md`는 Codex용 진입점입니다.
- 공통 규칙은 `docs/rules/`를 기준으로 유지합니다.

## 작업 체크리스트

- 기존 변경 확인
- YAML/JSON 문법 검사
- shell script는 `bash -n` 검사
- 링크 검사와 `git diff --check` 수행
