# Replication 정책

Harbor 간 또는 Harbor와 외부 Registry 간에 이미지를 자동으로 동기화합니다.

---

## Replication 개요

```
[소스 Registry]  ──Push Replication──▶  [Harbor]
[Harbor]         ──Pull Replication──▶  [대상 Registry]
```

| 방향 | 설명 | 주요 용도 |
|---|---|---|
| **Push Replication** | Harbor → 외부 Registry로 Push | Harbor를 소스로 다른 Region에 배포 |
| **Pull Replication** | 외부 Registry → Harbor로 Pull | 외부 Registry 이미지를 Harbor로 동기화 |

---

## 주요 사용 사례

1. **멀티 리전 배포**: `ap-northeast-2` Harbor → `us-east-1` Harbor 복제
2. **DR(재해복구)**: Primary Harbor → Backup Harbor 지속 동기화
3. **온프레미스 ↔ 클라우드**: ECR ↔ Harbor 양방향 동기화
4. **개발 → 운영 프로모션**: Dev Harbor → Prod Harbor로 검증된 이미지만 복제

---

## 1. Endpoint 등록

Replication 대상이 되는 Registry를 먼저 등록합니다.

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# 대상 Harbor Registry 등록 (다른 Region)
curl -s -X POST "${HARBOR_URL}/api/v2.0/registries" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "harbor-us-east",
    "type": "harbor",
    "url": "https://harbor-us.example.com",
    "credential": {
      "access_key": "admin",
      "access_secret": "Harbor12345!"
    },
    "insecure": false
  }'

# ECR 등록
curl -s -X POST "${HARBOR_URL}/api/v2.0/registries" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ecr-prod",
    "type": "aws-ecr",
    "url": "https://<account-id>.dkr.ecr.us-east-1.amazonaws.com",
    "credential": {
      "access_key": "AWS_ACCESS_KEY_ID",
      "access_secret": "AWS_SECRET_ACCESS_KEY"
    }
  }'
```

---

## 2. Replication 정책 생성

### UI에서 생성

1. **Administration** → **Replications** → **NEW REPLICATION RULE**
2. 설정:

| 항목 | 값 | 설명 |
|---|---|---|
| Name | `backend-to-us-east` | 정책 이름 |
| Replication Mode | `Push-based` / `Pull-based` | 복제 방향 |
| Source Registry | Harbor (로컬) / 외부 Registry | |
| Destination Registry | `harbor-us-east` | 위에서 등록한 Endpoint |
| Source resource filter | `backend/**` | 복제할 이미지 필터 |
| Destination Namespace | `backend` | 대상 Registry 네임스페이스 |
| Trigger | `Event Based` / `Scheduled` / `Manual` | |
| Bandwidth | `-1` (무제한) | |
| Override | ✅ | 동일 태그 덮어쓰기 허용 |

### API로 생성

```bash
# 대상 Registry ID 확인
DEST_REGISTRY_ID=$(curl -s "${HARBOR_URL}/api/v2.0/registries?name=harbor-us-east" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[0].id')

# Replication 정책 생성 (Push, Event-based)
curl -s -X POST "${HARBOR_URL}/api/v2.0/replication/policies" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"backend-to-us-east\",
    \"description\": \"backend 프로젝트를 US-East Harbor로 복제\",
    \"enabled\": true,
    \"src_registry\": null,
    \"dest_registry\": {\"id\": ${DEST_REGISTRY_ID}},
    \"dest_namespace\": \"backend\",
    \"dest_namespace_replace_count\": 1,
    \"filters\": [
      {\"type\": \"name\", \"value\": \"backend/**\"},
      {\"type\": \"tag\",  \"value\": \"v*\"}
    ],
    \"trigger\": {
      \"type\": \"event_based\",
      \"trigger_settings\": {}
    },
    \"override\": true,
    \"speed\": -1
  }"
```

---

## 3. Trigger 유형 비교

| Trigger | 설명 | 적합한 상황 |
|---|---|---|
| **Event Based** | Push/Delete 이벤트 발생 즉시 복제 | 실시간 복제 (권장) |
| **Scheduled** | Cron 스케줄로 주기적 복제 | 대량 동기화, 야간 배치 |
| **Manual** | 수동으로 복제 실행 | 일회성 마이그레이션 |

---

## 4. Replication 실행 (수동)

```bash
# 정책 ID 확인
POLICY_ID=$(curl -s "${HARBOR_URL}/api/v2.0/replication/policies" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[] | select(.name=="backend-to-us-east") | .id')

# 수동 Replication 실행
curl -s -X POST "${HARBOR_URL}/api/v2.0/replication/executions" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d "{\"policy_id\": ${POLICY_ID}}"
```

---

## 5. Replication 상태 확인

```bash
# 실행 목록 확인
curl -s "${HARBOR_URL}/api/v2.0/replication/executions?policy_id=${POLICY_ID}" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.[] | {id: .id, status: .status, start_time: .start_time, succeed: .succeed, failed: .failed}'

# 실행 내 태스크 상세 확인
EXEC_ID=1
curl -s "${HARBOR_URL}/api/v2.0/replication/executions/${EXEC_ID}/tasks" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.[] | {resource_url: .resource_url, status: .status}'
```

---

## 필터 패턴 예시

| 패턴 | 설명 |
|---|---|
| `backend/**` | backend 프로젝트 전체 |
| `backend/my-api` | my-api 이미지만 |
| `**` | 전체 이미지 |
| Tag 필터 `v*` | v로 시작하는 태그만 |
| Tag 필터 `v[0-9]*` | SemVer 형식 태그만 |

---

## 멀티 리전 DR 구성 예시

```
[Seoul Harbor]    ──Event-based Push──▶  [Tokyo Harbor]
                  ──Event-based Push──▶  [US-East Harbor]

복제 정책:
- 이름: backend-dr-tokyo
  소스: backend/** (태그: v*)
  대상: harbor-tokyo
  트리거: Event Based

- 이름: backend-dr-us
  소스: backend/** (태그: v*)
  대상: harbor-us
  트리거: Event Based
```

---

## 주의사항

- Replication은 **태그 단위**로 동작합니다. `latest` 태그를 계속 덮어쓰는 경우 이전 다이제스트는 자동 삭제되지 않습니다.
- Pull Replication은 Harbor가 소스 Registry를 주기적으로 조회합니다. 소스 Registry의 Rate Limit에 주의하세요.
- 대용량 초기 동기화는 **Scheduled** 모드로 야간에 실행하는 것을 권장합니다.
