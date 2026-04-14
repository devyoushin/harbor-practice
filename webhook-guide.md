# Webhook 설정

Harbor의 이벤트(Push, 스캔 완료, 삭제 등)가 발생했을 때 외부 시스템에 HTTP 알림을 보냅니다.

---

## 지원 이벤트

| 이벤트 | 설명 |
|---|---|
| `PUSH_ARTIFACT` | 이미지 / Artifact Push 완료 |
| `PULL_ARTIFACT` | 이미지 / Artifact Pull |
| `DELETE_ARTIFACT` | 이미지 / Artifact 삭제 |
| `SCANNING_FAILED` | 이미지 스캔 실패 |
| `SCANNING_COMPLETED` | 이미지 스캔 완료 |
| `QUOTA_EXCEED` | 스토리지 할당량 초과 |
| `QUOTA_WARNING` | 스토리지 할당량 경고 임박 |
| `REPLICATION` | Replication 작업 완료 |

---

## Webhook 생성 (UI)

1. **Projects** → 해당 프로젝트 → **Webhooks** → **NEW WEBHOOK**
2. 설정:
   - Name: `slack-notification`
   - Notify Type: `HTTP` 또는 `Slack`
   - Endpoint URL: 알림 받을 엔드포인트
   - Auth Header: 인증 헤더 (선택)
   - Events: 알림 받을 이벤트 선택
3. **CONTINUE** 클릭

---

## Webhook 생성 (API)

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

curl -s -X POST "${HARBOR_URL}/api/v2.0/projects/backend/webhookpolicies" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "push-notification",
    "description": "이미지 Push 시 알림",
    "enabled": true,
    "targets": [
      {
        "type": "http",
        "address": "https://webhook.example.com/harbor",
        "auth_header": "Authorization: Bearer my-secret-token",
        "skip_cert_verify": false
      }
    ],
    "event_types": [
      "PUSH_ARTIFACT",
      "SCANNING_COMPLETED",
      "SCANNING_FAILED"
    ]
  }'
```

---

## Webhook 페이로드 형식

### PUSH_ARTIFACT 이벤트

```json
{
  "type": "PUSH_ARTIFACT",
  "occur_at": 1713052800,
  "operator": "robot$backend+ci-pusher",
  "event_data": {
    "resources": [
      {
        "digest": "sha256:abc123...",
        "tag": "v1.0.0",
        "resource_url": "harbor.example.com/backend/my-api:v1.0.0"
      }
    ],
    "repository": {
      "name": "my-api",
      "namespace": "backend",
      "full_name": "backend/my-api",
      "type": "private"
    }
  }
}
```

### SCANNING_COMPLETED 이벤트

```json
{
  "type": "SCANNING_COMPLETED",
  "occur_at": 1713052900,
  "operator": "auto",
  "event_data": {
    "resources": [
      {
        "digest": "sha256:abc123...",
        "tag": "v1.0.0",
        "resource_url": "harbor.example.com/backend/my-api:v1.0.0",
        "scan_overview": {
          "application/vnd.security.vulnerability.report; version=1.1": {
            "scan_status": "Success",
            "severity": "High",
            "summary": {
              "total": 5,
              "fixable": 3,
              "critical": 0,
              "high": 2,
              "medium": 3
            }
          }
        }
      }
    ],
    "repository": {
      "name": "my-api",
      "namespace": "backend"
    }
  }
}
```

---

## Slack 알림 연동

Harbor는 Slack Webhook을 네이티브로 지원합니다.

1. Slack에서 Incoming Webhook URL 생성:
   - Slack App → Incoming Webhooks → Add New Webhook to Workspace
   - Webhook URL 복사: `https://hooks.slack.com/services/T.../B.../...`

2. Harbor Webhook 생성:

```bash
curl -s -X POST "${HARBOR_URL}/api/v2.0/projects/backend/webhookpolicies" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "slack-alert",
    "enabled": true,
    "targets": [
      {
        "type": "slack",
        "address": "https://hooks.slack.com/services/T.../B.../..."
      }
    ],
    "event_types": [
      "PUSH_ARTIFACT",
      "SCANNING_FAILED",
      "QUOTA_EXCEED"
    ]
  }'
```

---

## 수신 서버 구현 예시 (Node.js)

```javascript
const express = require('express');
const app = express();
app.use(express.json());

app.post('/harbor', (req, res) => {
  const { type, event_data } = req.body;

  if (type === 'PUSH_ARTIFACT') {
    const { repository, resources } = event_data;
    const tag = resources[0]?.tag;
    console.log(`[PUSH] ${repository.full_name}:${tag}`);
    // ArgoCD sync 트리거, Slack 알림 등 후처리
  }

  if (type === 'SCANNING_COMPLETED') {
    const scan = resources[0]?.scan_overview;
    const severity = scan?.severity;
    if (severity === 'Critical') {
      // Critical 취약점 발견 시 알림 전송
      console.log(`[CRITICAL VULN] ${event_data.repository.full_name}`);
    }
  }

  res.status(200).send('OK');
});

app.listen(8080);
```

---

## Webhook 테스트

```bash
# Webhook 테스트 전송 (UI)
# Projects → Webhooks → 해당 Webhook → TEST

# API로 테스트
WEBHOOK_ID=1
curl -s -X POST \
  "${HARBOR_URL}/api/v2.0/projects/backend/webhookpolicies/${WEBHOOK_ID}/executions" \
  -u "${HARBOR_USER}:${HARBOR_PASS}"
```

---

## Webhook 실행 기록 확인

```bash
# 최근 Webhook 실행 로그
WEBHOOK_ID=1
curl -s \
  "${HARBOR_URL}/api/v2.0/projects/backend/webhookpolicies/${WEBHOOK_ID}/executions?page=1&page_size=10" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  | jq '.[] | {id: .id, status: .status_code, creation_time: .creation_time}'
```
