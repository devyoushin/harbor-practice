# 트러블슈팅 가이드

Harbor 운영 중 자주 발생하는 문제와 해결 방법을 정리합니다.

---

## 기본 진단 명령어

```bash
# 전체 파드 상태 확인
kubectl get pods -n harbor -o wide

# 파드 로그 확인
kubectl logs -n harbor deployment/harbor-core --tail=100
kubectl logs -n harbor deployment/harbor-registry --tail=100
kubectl logs -n harbor deployment/harbor-jobservice --tail=100
kubectl logs -n harbor statefulset/harbor-trivy --tail=100

# 이벤트 확인
kubectl get events -n harbor --sort-by='.lastTimestamp' | tail -20

# 리소스 사용량
kubectl top pods -n harbor
```

---

## 문제 유형별 해결 방법

### 1. `docker login` 실패

**증상**
```
Error response from daemon: Get "https://harbor.example.com/v2/": x509: certificate signed by unknown authority
```

**원인**: 자체 서명 인증서 또는 내부 CA 인증서를 Docker가 신뢰하지 않음

**해결**
```bash
# 방법 1: Harbor CA 인증서를 Docker에 등록
# Harbor UI → Administration → Configuration → System Settings → Download Root Cert

sudo mkdir -p /etc/docker/certs.d/harbor.example.com
sudo cp harbor.crt /etc/docker/certs.d/harbor.example.com/ca.crt
sudo systemctl restart docker

# 방법 2: containerd 사용 시
sudo mkdir -p /etc/containerd/certs.d/harbor.example.com
cat << EOF | sudo tee /etc/containerd/certs.d/harbor.example.com/hosts.toml
server = "https://harbor.example.com"
[host."https://harbor.example.com"]
  ca = "/etc/ssl/certs/harbor-ca.crt"
EOF
sudo systemctl restart containerd
```

---

### 2. 이미지 Push 실패 (401 Unauthorized)

**증상**
```
unauthorized: unauthorized to access repository: backend/my-api, action: push
```

**원인**: 로그인이 안 되어 있거나 해당 프로젝트에 Push 권한이 없음

**해결**
```bash
# 현재 로그인 상태 확인
cat ~/.docker/config.json | jq '.auths["harbor.example.com"]'

# 재로그인
docker logout harbor.example.com
docker login harbor.example.com -u admin -p Harbor12345!

# Robot Account인 경우 권한 확인
curl -s "https://harbor.example.com/api/v2.0/projects/backend/robots" \
  -u "admin:Harbor12345!" | jq '.[] | {name: .name, disabled: .disabled}'
```

---

### 3. 이미지 Pull 차단 (취약점 정책)

**증상**
```
Error response from daemon: unknown: Current image with 3 vulnerability is not allowed to pull
due to configured policy.
```

**원인**: 프로젝트의 "Prevent vulnerable images" 정책에 의해 차단됨

**해결**
```bash
# 방법 1: 이미지를 패치하여 취약점 수정 후 재Push

# 방법 2: 해당 CVE를 허용 목록에 추가 (임시 조치)
curl -s -X PUT "https://harbor.example.com/api/v2.0/projects/backend" \
  -u "admin:Harbor12345!" \
  -H "Content-Type: application/json" \
  -d '{
    "cve_allowlist": {
      "items": [{"cve_id": "CVE-2023-XXXXX"}]
    }
  }'

# 방법 3: 정책 일시적 비활성화 (운영 환경에서는 비권장)
# Projects → Configuration → Prevent vulnerable images → 비활성화
```

---

### 4. Trivy 스캔 실패

**증상**: 스캔 결과가 "Error" 상태

**진단**
```bash
# Trivy 파드 로그 확인
kubectl logs -n harbor statefulset/harbor-trivy --tail=100

# 일반적인 오류 메시지
# "failed to update the vulnerability database"
# "dial tcp: connection timed out"
```

**해결**
```bash
# Trivy 취약점 DB 업데이트 실패 (인터넷 접속 문제)
# 1. 노드의 아웃바운드 인터넷 접근 확인
kubectl exec -n harbor statefulset/harbor-trivy -- \
  curl -v https://ghcr.io/aquasecurity/trivy-db

# 2. Trivy DB를 S3/사설 OCI Registry에서 받도록 설정 (오프라인 환경)
# harbor-values.yaml에서 trivy.dbRepository 설정

# 3. Trivy 재시작
kubectl rollout restart statefulset/harbor-trivy -n harbor
```

---

### 5. Core 파드 재시작 반복 (CrashLoopBackOff)

**진단**
```bash
kubectl logs -n harbor deployment/harbor-core --previous --tail=100
```

**일반적인 원인 및 해결**

| 오류 메시지 | 원인 | 해결 |
|---|---|---|
| `failed to connect to database` | PostgreSQL 연결 실패 | PostgreSQL 파드 상태 및 비밀번호 확인 |
| `failed to connect to redis` | Redis 연결 실패 | Redis 파드 상태 및 비밀번호 확인 |
| `invalid configuration` | values.yaml 설정 오류 | `helm get values harbor -n harbor` 로 현재 설정 확인 |

```bash
# PostgreSQL 연결 테스트
kubectl exec -n harbor -it harbor-postgresql-0 -- \
  psql -U postgres -c "\l"

# Redis 연결 테스트
kubectl exec -n harbor -it harbor-redis-master-0 -- \
  redis-cli -a <redis-password> ping
```

---

### 6. Registry 스토리지 용량 부족

**증상**: Push 실패, `no space left on device`

**진단**
```bash
# PVC 용량 확인
kubectl get pvc -n harbor

# 실제 사용량 확인
kubectl exec -n harbor deployment/harbor-registry -- \
  df -h /storage
```

**해결**
```bash
# 방법 1: 보존 정책 즉시 실행 + Garbage Collection
# Harbor UI → Projects → Policy → TAG RETENTION → Run Now
# Harbor UI → Administration → Garbage Collection → GC Now

# 방법 2: PVC 용량 확장 (StorageClass가 allowVolumeExpansion 지원 시)
kubectl patch pvc harbor-registry \
  -n harbor \
  -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'
```

---

### 7. Replication 실패

**진단**
```bash
# Jobservice 로그 확인
kubectl logs -n harbor deployment/harbor-jobservice --tail=100 | grep -i "replication\|error"

# Replication 실행 기록 확인
curl -s "https://harbor.example.com/api/v2.0/replication/executions" \
  -u "admin:Harbor12345!" | jq '.[] | {id: .id, status: .status, failed: .failed}'
```

**일반적인 원인**

| 원인 | 해결 방법 |
|---|---|
| 대상 Registry 인증 실패 | Endpoint 자격증명 재확인 및 업데이트 |
| 대상 Registry 네트워크 차단 | Security Group, NACLs, 방화벽 규칙 확인 |
| 대상 프로젝트 없음 | 대상 Harbor에 동일한 프로젝트 생성 |

---

### 8. 웹 UI 접근 불가

```bash
# Ingress 상태 확인
kubectl describe ingress -n harbor

# Nginx 파드 상태
kubectl logs -n harbor -l component=nginx --tail=50

# 서비스 엔드포인트 확인
kubectl get endpoints -n harbor
```

---

## 유용한 디버깅 명령어 모음

```bash
# Harbor Core API 헬스체크
curl -sk "https://harbor.example.com/api/v2.0/health" | jq .

# 전체 컴포넌트 상태 확인
curl -sk "https://harbor.example.com/api/v2.0/health" \
  -u "admin:Harbor12345!" | jq '.components[] | {name: .name, status: .status}'

# 시스템 정보
curl -sk "https://harbor.example.com/api/v2.0/systeminfo" \
  -u "admin:Harbor12345!" | jq '{harbor_version, with_trivy, storage_per_project}'

# 현재 스케줄된 작업 목록
curl -sk "https://harbor.example.com/api/v2.0/system/gc/schedule" \
  -u "admin:Harbor12345!" | jq .
```

---

## 로그 레벨 조정 (디버깅 시)

```yaml
# harbor-values.yaml
logLevel: debug  # info (기본), debug, warning, error
```

```bash
helm upgrade harbor bitnami/harbor \
  -n harbor \
  --reuse-values \
  --set logLevel=debug
```
