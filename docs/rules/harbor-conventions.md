# Harbor 표준 관행

## 프로젝트 명명 규칙

```
harbor.example.com/<team>/<app>:<version>
예: harbor.example.com/platform/nginx:1.21.0
    harbor.example.com/team-a/backend:v2.1.0
```

## 로봇 계정 설계

```
이름: robot$<team>-<app>-<env>
범위: 프로젝트 단위 (시스템 전체 금지)
권한: push (CI/CD), pull (배포)
만료: 90일 (자동 갱신 스크립트 필요)
```

## 이미지 태그 전략

```
latest      → 금지 (Harbor 보존 정책에서 제외 불가)
stable      → 프로덕션 기준 태그
v1.2.3      → SemVer 릴리즈 태그
main-abc123 → 브랜치-커밋 태그 (CI/CD)
```

## 보존 정책 표준

```
- 최근 10개 태그 유지
- stable, v* 태그 영구 보존
- 90일 이상 미사용 이미지 삭제
```

## Harbor API 인증

```bash
# 로봇 계정 토큰
export HARBOR_TOKEN=$(echo -n "robot\$name:secret" | base64)
curl -H "Authorization: Basic $HARBOR_TOKEN" \
  https://harbor.example.com/api/v2.0/...
```

## 절대 하지 말 것
- 관리자 계정(admin)을 CI/CD에 직접 사용
- 로봇 계정 시스템 전체 권한 부여
- Public 프로젝트로 민감 이미지 공개
- 가비지 컬렉션 없이 이미지 무제한 축적
