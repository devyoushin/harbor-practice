# End-to-End 실습: 빌드 → 스캔 → 배포

Harbor의 핵심 기능을 처음부터 끝까지 실습합니다.

---

## 실습 목표

```
[로컬 빌드]
    │
    ▼
[Harbor Push]  ←  자동 취약점 스캔
    │
    ▼
[스캔 결과 확인]  →  Critical 없음 확인
    │
    ▼
[Kubernetes 배포]  ←  Harbor에서 이미지 Pull
    │
    ▼
[트래픽 확인]
```

---

## 사전 조건

```bash
# Harbor 접속 확인
curl -sk "https://harbor.example.com/api/v2.0/health" | jq '.status'
# "healthy"

# Kubernetes 접속 확인
kubectl get nodes

# Docker 로그인
docker login harbor.example.com -u admin -p Harbor12345!
```

---

## Step 1: 프로젝트 및 Robot Account 생성

```bash
HARBOR_URL="https://harbor.example.com"
HARBOR_USER="admin"
HARBOR_PASS="Harbor12345!"

# 1-1. 프로젝트 생성 (자동 스캔 활성화)
curl -s -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "practice",
    "public": false,
    "metadata": {
      "auto_scan": "true"
    }
  }'

echo "✅ 프로젝트 생성 완료"

# 1-2. Robot Account 생성
ROBOT_RESP=$(curl -s -X POST "${HARBOR_URL}/api/v2.0/projects/practice/robots" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ci-pusher",
    "description": "실습용 Robot Account",
    "duration": 30,
    "permissions": [
      {
        "kind": "project",
        "namespace": "practice",
        "access": [
          {"resource": "repository", "action": "push"},
          {"resource": "repository", "action": "pull"}
        ]
      }
    ]
  }')

ROBOT_NAME=$(echo $ROBOT_RESP | jq -r '.name')
ROBOT_SECRET=$(echo $ROBOT_RESP | jq -r '.secret')

echo "✅ Robot Account 생성 완료"
echo "   이름: ${ROBOT_NAME}"
echo "   Secret: ${ROBOT_SECRET}"
# ⚠️ Secret을 안전한 곳에 저장하세요
```

---

## Step 2: 샘플 애플리케이션 빌드 및 Push

```bash
# 2-1. 간단한 Dockerfile 작성
mkdir -p /tmp/practice-app
cat << 'EOF' > /tmp/practice-app/Dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
EOF

cat << 'EOF' > /tmp/practice-app/index.html
<!DOCTYPE html>
<html>
<body>
  <h1>Harbor Practice App v1.0.0</h1>
</body>
</html>
EOF

cd /tmp/practice-app

# 2-2. 이미지 빌드
docker build -t practice-app:v1.0.0 .

# 2-3. Harbor 태그 지정
docker tag practice-app:v1.0.0 harbor.example.com/practice/practice-app:v1.0.0

# 2-4. Robot Account로 로그인 후 Push
docker login harbor.example.com \
  -u "${ROBOT_NAME}" \
  -p "${ROBOT_SECRET}"

docker push harbor.example.com/practice/practice-app:v1.0.0
echo "✅ 이미지 Push 완료"
```

---

## Step 3: 스캔 결과 확인

```bash
# 3-1. 스캔 완료 대기 (자동 스캔이므로 30초~2분 소요)
echo "스캔 완료 대기 중..."
sleep 60

# 3-2. 스캔 결과 조회
SCAN_RESULT=$(curl -s \
  "${HARBOR_URL}/api/v2.0/projects/practice/repositories/practice-app/artifacts/v1.0.0/additions/vulnerabilities" \
  -u "${HARBOR_USER}:${HARBOR_PASS}")

echo "=== 스캔 결과 ==="
echo $SCAN_RESULT | jq \
  '."application/vnd.security.vulnerability.report; version=1.1".summary'

# 3-3. Critical 취약점 확인
CRITICAL_COUNT=$(echo $SCAN_RESULT | jq \
  '."application/vnd.security.vulnerability.report; version=1.1".summary.critical // 0')

if [ "$CRITICAL_COUNT" -gt "0" ]; then
  echo "❌ Critical 취약점 ${CRITICAL_COUNT}개 발견! 배포를 중단합니다."
  exit 1
else
  echo "✅ Critical 취약점 없음. 배포를 진행합니다."
fi
```

---

## Step 4: Kubernetes 배포

```bash
# 4-1. imagePullSecret 생성
kubectl create secret docker-registry harbor-practice-creds \
  --docker-server=harbor.example.com \
  --docker-username="${ROBOT_NAME}" \
  --docker-password="${ROBOT_SECRET}" \
  --namespace default

echo "✅ imagePullSecret 생성 완료"

# 4-2. Deployment 배포
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: practice-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: practice-app
  template:
    metadata:
      labels:
        app: practice-app
    spec:
      containers:
      - name: practice-app
        image: harbor.example.com/practice/practice-app:v1.0.0
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
      imagePullSecrets:
      - name: harbor-practice-creds
---
apiVersion: v1
kind: Service
metadata:
  name: practice-app
  namespace: default
spec:
  selector:
    app: practice-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# 4-3. 배포 상태 확인
kubectl rollout status deployment/practice-app -n default
echo "✅ 배포 완료"
```

---

## Step 5: 트래픽 확인

```bash
# 5-1. 파드 확인
kubectl get pods -l app=practice-app -n default

# 5-2. 포트 포워드로 접근 테스트
kubectl port-forward svc/practice-app 8080:80 -n default &
sleep 2
curl http://localhost:8080
# Harbor Practice App v1.0.0 출력 확인
kill %1

echo "✅ 트래픽 확인 완료"
```

---

## Step 6: 이미지 업데이트 (Rolling Update)

```bash
# 6-1. v2.0.0 이미지 빌드
cat << 'EOF' > /tmp/practice-app/index.html
<!DOCTYPE html>
<html>
<body>
  <h1>Harbor Practice App v2.0.0</h1>
  <p>Updated via Harbor!</p>
</body>
</html>
EOF

docker build -t harbor.example.com/practice/practice-app:v2.0.0 /tmp/practice-app/
docker push harbor.example.com/practice/practice-app:v2.0.0

# 6-2. 스캔 완료 대기
echo "v2.0.0 스캔 대기 중..."
sleep 60

# 6-3. 이미지 업데이트
kubectl set image deployment/practice-app \
  practice-app=harbor.example.com/practice/practice-app:v2.0.0 \
  -n default

kubectl rollout status deployment/practice-app -n default
echo "✅ v2.0.0 업데이트 완료"
```

---

## Step 7: Tag 보존 정책 설정

```bash
# 7-1. v* 태그는 항상 유지, 나머지는 최신 5개만 유지
PROJECT_ID=$(curl -s "${HARBOR_URL}/api/v2.0/projects?name=practice" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" | jq '.[0].id')

curl -s -X POST "${HARBOR_URL}/api/v2.0/retentions" \
  -u "${HARBOR_USER}:${HARBOR_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"algorithm\": \"or\",
    \"rules\": [
      {
        \"disabled\": false,
        \"action\": \"retain\",
        \"template\": \"always\",
        \"tag_selectors\": [{\"kind\": \"doublestar\", \"decoration\": \"matches\", \"pattern\": \"v*\"}],
        \"scope_selectors\": {\"repository\": [{\"kind\": \"doublestar\", \"decoration\": \"repoMatches\", \"pattern\": \"**\"}]}
      }
    ],
    \"trigger\": {\"kind\": \"Schedule\", \"settings\": {\"cron\": \"0 0 0 * * *\"}},
    \"scope\": {\"level\": \"project\", \"ref\": ${PROJECT_ID}}
  }"

echo "✅ Tag 보존 정책 설정 완료"
```

---

## 실습 정리

```bash
# Deployment 및 Service 삭제
kubectl delete deployment practice-app -n default
kubectl delete service practice-app -n default
kubectl delete secret harbor-practice-creds -n default

# Harbor 이미지 삭제 (선택)
# Harbor UI → Projects → practice → Repositories → 태그 선택 → DELETE

echo "✅ 실습 리소스 정리 완료"
```

---

## 실습 완료 체크리스트

- [ ] Harbor 프로젝트 생성 (자동 스캔 활성화)
- [ ] Robot Account 생성 및 토큰 발급
- [ ] 이미지 빌드 및 Harbor에 Push
- [ ] Trivy 스캔 결과 확인 (Critical 취약점 없음)
- [ ] Kubernetes imagePullSecret 생성
- [ ] Deployment 배포 및 트래픽 확인
- [ ] 이미지 버전 업데이트 (Rolling Update)
- [ ] Tag 보존 정책 설정
