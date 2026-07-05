# Harbor 대규모 HA 아키텍처 및 백업 구성

> **카테고리**: 운영 / 아키텍처
> **관련 버전**: Harbor 2.x
> **작성일**: 2026-04-20

---

## 1. 개요

Harbor HA의 핵심 원리는 **Harbor 프로세스를 Stateless하게 만들고, 상태(이미지·메타데이터·세션)를 공유 외부 저장소로 분리**하는 것입니다.
이렇게 하면 Harbor 인스턴스를 몇 개든 수평 확장할 수 있고, 어느 인스턴스가 요청을 받아도 동일하게 동작합니다.

이 가이드는 두 가지 배포 방식을 모두 다룹니다.

| 구분 | 방식 A | 방식 B |
|---|---|---|
| Harbor 배포 | **Docker Compose + VM 이중화** | **Kubernetes (EKS) Pod** |
| 이미지 스토리지 | **온프레미스 (Ceph / MinIO / NFS)** | **AWS S3** |
| 대상 환경 | 온프레미스 / 프라이빗 클라우드 | AWS 퍼블릭 클라우드 |

---

## 2. HA 구조 원리

```
        클라이언트 (docker push/pull)
                    │
                    ▼
          ┌─────────────────┐
          │    L4/L7 LB     │  ← 단일 진입점, Harbor 앞에만 필요
          └────────┬────────┘
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
   [Harbor 인스턴스 1]  [Harbor 인스턴스 2]   ← Stateless, 수평 확장
         │                   │
         └─────────┬─────────┘
                   │ 모든 인스턴스가 동일 저장소 바라봄
         ┌─────────┼─────────┐
         ▼         ▼         ▼
   [Object Storage] [PostgreSQL] [Redis]
   (이미지 레이어)  (메타데이터)  (세션/캐시/큐)
```

**스토리지에는 LB가 필요하지 않습니다.**
- Object Storage(S3/Ceph/MinIO)는 Harbor가 직접 API로 연결
- PostgreSQL / Redis는 Harbor 설정 파일에 호스트를 직접 지정
- LB는 오직 "클라이언트 → Harbor 인스턴스" 구간에만 위치

---

## 3. 방식 A — Docker Compose + VM 이중화 (온프레미스)

### 3.1 전체 아키텍처

```
                  ┌─────────────────────────────────────────┐
  클라이언트      │           온프레미스 데이터센터           │
  docker push ──▶│                                         │
                  │   ┌───────────────────────────────┐     │
                  │   │  Nginx / HAProxy (LB VM)      │     │
                  │   │  VIP: 10.0.0.10 (VRRP/Keepalived)  │
                  │   └──────────────┬────────────────┘     │
                  │                  │                       │
                  │        ┌─────────┴─────────┐            │
                  │        ▼                   ▼            │
                  │  ┌───────────┐       ┌───────────┐     │
                  │  │ Harbor VM1│       │ Harbor VM2│     │
                  │  │10.0.0.11  │       │10.0.0.12  │     │
                  │  │(docker-   │       │(docker-   │     │
                  │  │ compose)  │       │ compose)  │     │
                  │  └─────┬─────┘       └─────┬─────┘     │
                  │        └─────────┬─────────┘            │
                  │                  │                       │
                  │    ┌─────────────┼──────────────┐       │
                  │    ▼             ▼              ▼       │
                  │ ┌────────┐ ┌─────────┐ ┌─────────┐    │
                  │ │ Ceph   │ │Postgres │ │  Redis  │    │
                  │ │(또는   │ │Sentinel │ │Sentinel │    │
                  │ │ MinIO) │ │ HA      │ │ HA      │    │
                  │ └────────┘ └─────────┘ └─────────┘    │
                  └─────────────────────────────────────────┘
```

### 3.2 LB 구성 — Nginx + Keepalived (Active/Passive)

LB VM 2대를 두고 Keepalived로 VIP(Virtual IP)를 공유합니다. Primary LB 장애 시 VIP가 Secondary로 자동 이동합니다.

```bash
# LB VM 공통: Nginx + Keepalived 설치 (Ubuntu 기준)
apt-get install -y nginx keepalived
```

```nginx
# /etc/nginx/nginx.conf (LB VM 1, 2 동일)

events { worker_connections 1024; }

# Harbor는 HTTP/HTTPS 외에 docker 프로토콜(TCP)도 처리 — stream 블록 사용
stream {
  upstream harbor_https {
    least_conn;
    server 10.0.0.11:443;
    server 10.0.0.12:443;
  }

  server {
    listen 443;
    proxy_pass harbor_https;
    proxy_connect_timeout 10s;
    proxy_timeout 300s;      # 대용량 이미지 push 시 타임아웃 방지
  }
}

http {
  upstream harbor_http {
    least_conn;
    server 10.0.0.11:80;
    server 10.0.0.12:80;
  }

  server {
    listen 80;
    # HTTP → HTTPS 리다이렉트
    return 301 https://$host$request_uri;
  }
}
```

```bash
# /etc/keepalived/keepalived.conf (LB Primary VM)
vrrp_script chk_nginx {
    script "nginx -t 2>/dev/null && pidof nginx > /dev/null"
    interval 2
    weight -20
}

vrrp_instance VI_HARBOR {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 110          # Secondary는 100으로 설정
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass harbor_lb_secret
    }

    virtual_ipaddress {
        10.0.0.10/24      # VIP — DNS에 harbor.example.com으로 등록
    }

    track_script {
        chk_nginx
    }
}
```

```bash
systemctl enable --now keepalived nginx
```

### 3.3 Harbor VM — docker-compose.yml 구성 핵심 포인트

Harbor 공식 installer의 `harbor.yml`에서 외부 DB/Redis/스토리지를 지정합니다.

```yaml
# harbor.yml (Harbor VM 1, 2 동일하게 적용)

hostname: harbor.example.com

https:
  port: 443
  certificate: /opt/harbor/certs/harbor.crt
  private_key: /opt/harbor/certs/harbor.key

# ── 외부 DB (PostgreSQL HA) ──────────────────────────────
database:
  external:
    host: 10.0.0.20          # PostgreSQL VIP or Primary 호스트
    port: 5432
    username: harbor
    password: <DB_PASSWORD>
    coreDatabase: registry
    sslmode: disable

# ── 외부 Redis (Sentinel HA) ────────────────────────────
redis:
  external:
    addr: "10.0.0.30:26379,10.0.0.31:26379,10.0.0.32:26379"  # Sentinel 주소
    sentinelMasterSet: mymaster
    password: <REDIS_PASSWORD>
    db: 0

# ── 이미지 스토리지 → 섹션 4에서 선택 ──────────────────
storage_service:
  # 온프레미스는 섹션 4-A, 클라우드는 섹션 4-B 참고
```

```bash
# Harbor 설치 (VM 1, 2 동일하게 실행)
cd /opt/harbor
./prepare         # harbor.yml → docker-compose.yml 생성
docker compose up -d

# 서비스 확인
docker compose ps
curl -k https://localhost/api/v2.0/health | jq .
```

### 3.4 PostgreSQL HA — Patroni (또는 단순 Primary/Standby)

온프레미스에서 PostgreSQL HA를 구성하는 가장 실용적인 방법은 **Patroni + etcd**입니다.
단순한 환경이라면 Primary/Standby + pgBouncer VIP 방식으로도 충분합니다.

```bash
# Patroni를 사용하는 경우 — VM 3대 구성 예시
# patroni.yml 핵심 설정

scope: harbor-pg
name: pg-node1

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 30
    maximum_lag_on_failover: 1048576

  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.0.0.21:5432
  data_dir: /var/lib/postgresql/15/main
  authentication:
    replication:
      username: replicator
      password: <REPL_PASSWORD>
    superuser:
      username: postgres
      password: <PG_PASSWORD>
```

```bash
# Harbor가 사용할 DB 및 유저 생성
psql -U postgres -c "CREATE USER harbor WITH PASSWORD '<PASSWORD>';"
psql -U postgres -c "CREATE DATABASE registry OWNER harbor;"
```

### 3.5 Redis HA — Sentinel 모드

```bash
# redis.conf (Primary)
bind 0.0.0.0
requirepass <REDIS_PASSWORD>
masterauth <REDIS_PASSWORD>

# sentinel.conf (VM 3대에 동일 적용)
sentinel monitor mymaster 10.0.0.30 6379 2
sentinel auth-pass mymaster <REDIS_PASSWORD>
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 30000
```

---

## 4. 스토리지 구성

### 4-A. 온프레미스 Object Storage

Harbor는 이미지 레이어를 저장할 때 **S3 호환 API**를 사용합니다. 온프레미스에서는 아래 솔루션 중 하나를 선택합니다.

| 솔루션 | 특징 | 추천 규모 |
|---|---|---|
| **MinIO** | 설치 간단, S3 완벽 호환, 단일 바이너리 | 소~중규모, 빠른 구성 |
| **Ceph RGW** | 엔터프라이즈급 확장성, RADOS 기반 이중화 | 대규모, 전용 스토리지 팀 있을 때 |
| **NFS** | 구성 단순, 기존 인프라 활용 | 소규모, 성능 요구사항 낮을 때 |

#### 4-A-1. MinIO (가장 일반적인 온프레미스 선택)

```bash
# MinIO 분산 모드 설치 (VM 4대, 각 VM에 디스크 2개 = 총 8 드라이브)
# ERASURE CODING으로 드라이브 2개까지 장애 허용

# 각 MinIO VM에서 실행
docker run -d \
  --name minio \
  --network host \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=<MINIO_PASSWORD> \
  -v /data1:/data1 -v /data2:/data2 \
  quay.io/minio/minio server \
  http://10.0.0.{40...43}/data{1...2} \
  --console-address ":9001"

# MinIO Client로 Harbor 전용 버킷 생성
docker run --rm quay.io/minio/mc \
  alias set local http://10.0.0.40:9000 minioadmin <MINIO_PASSWORD>

docker run --rm quay.io/minio/mc mb local/harbor-registry
docker run --rm quay.io/minio/mc policy set private local/harbor-registry
```

```yaml
# harbor.yml — MinIO 스토리지 설정
storage_service:
  s3:
    accesskey: minioadmin
    secretkey: <MINIO_PASSWORD>
    regionendpoint: http://10.0.0.40:9000    # MinIO LB IP (Nginx로 구성)
    bucket: harbor-registry
    region: us-east-1                         # MinIO는 region 값 무관, 임의 지정
    encrypt: false
    secure: false                             # HTTP 내부망이면 false
    v4auth: true
    chunksize: "5242880"
    rootdirectory: /
```

#### 4-A-2. Ceph RGW

```yaml
# harbor.yml — Ceph RGW 스토리지 설정
storage_service:
  s3:
    accesskey: <CEPH_ACCESS_KEY>
    secretkey: <CEPH_SECRET_KEY>
    regionendpoint: http://ceph-rgw.internal:7480
    bucket: harbor-registry
    region: default
    encrypt: false
    secure: false
    v4auth: true
    chunksize: "5242880"
    rootdirectory: /
```

```bash
# Ceph에서 Harbor용 사용자 및 버킷 생성
radosgw-admin user create \
  --uid harbor \
  --display-name "Harbor Registry" \
  --access-key <ACCESS_KEY> \
  --secret <SECRET_KEY>

radosgw-admin bucket create \
  --bucket harbor-registry \
  --uid harbor
```

#### 4-A-3. NFS (소규모 / 기존 인프라 활용)

NFS는 S3 API를 지원하지 않으므로 Harbor storage driver를 `filesystem`으로 설정하고, NFS 마운트를 공유합니다.

```bash
# NFS 서버에서 Harbor 볼륨 디렉토리 export
echo "/harbor-data  10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
exportfs -ra

# Harbor VM 1, 2에서 NFS 마운트
mount -t nfs 10.0.0.50:/harbor-data /data/harbor-registry
echo "10.0.0.50:/harbor-data /data/harbor-registry nfs defaults,_netdev 0 0" >> /etc/fstab
```

```yaml
# harbor.yml — NFS(filesystem) 스토리지 설정
storage_service:
  filesystem:
    rootdirectory: /data/harbor-registry   # NFS 마운트 경로
```

> **NFS 주의사항**: 동시 write I/O가 많으면 성능 병목이 생깁니다. 1TB 초과 또는 push 빈도가 높은 환경에서는 MinIO/Ceph를 권장합니다.

---

### 4-B. 클라우드 Object Storage — AWS S3

#### Harbor Pod (K8s/EKS) 설정

```yaml
# values-ha.yaml
persistence:
  imageChartStorage:
    type: s3
    s3:
      region: ap-northeast-2
      bucket: harbor-registry-prod
      regionendpoint: ""          # AWS S3는 비워둠
      encrypt: true
      secure: true
      v4auth: true
      chunksize: "5242880"
      rootdirectory: /registry
      storageclass: STANDARD
```

#### IRSA 구성 (EKS에서 인증키 없이 S3 접근)

```bash
# IAM Policy 생성
cat > harbor-s3-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],
      "Resource": "arn:aws:s3:::harbor-registry-prod"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:AbortMultipartUpload", "s3:DeleteObject", "s3:GetObject",
                 "s3:ListMultipartUploadParts", "s3:PutObject"],
      "Resource": "arn:aws:s3:::harbor-registry-prod/*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name HarborS3Policy \
  --policy-document file://harbor-s3-policy.json

eksctl create iamserviceaccount \
  --cluster <CLUSTER_NAME> --namespace harbor \
  --name harbor-registry \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/HarborS3Policy \
  --approve --region ap-northeast-2
```

#### S3 버킷 기본 설정

```bash
# 버킷 생성
aws s3api create-bucket \
  --bucket harbor-registry-prod \
  --region ap-northeast-2 \
  --create-bucket-configuration LocationConstraint=ap-northeast-2

# 버전 관리 + 암호화 + 퍼블릭 차단
aws s3api put-bucket-versioning \
  --bucket harbor-registry-prod \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket harbor-registry-prod \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket harbor-registry-prod \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# S3 VPC Gateway Endpoint (무료, 내부망 라우팅)
aws ec2 create-vpc-endpoint \
  --vpc-id <VPC_ID> \
  --service-name com.amazonaws.ap-northeast-2.s3 \
  --route-table-ids <ROUTE_TABLE_IDS>
```

---

## 5. Harbor 배포 — K8s (방식 B) 핵심 설정

```yaml
# values-ha.yaml — EKS 멀티 AZ HA
core:
  replicaCount: 3
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/component
                operator: In
                values: ["core"]
          topologyKey: "topology.kubernetes.io/zone"

registry:
  replicaCount: 3
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/component
                operator: In
                values: ["registry"]
          topologyKey: "topology.kubernetes.io/zone"

jobservice:
  replicaCount: 2

# 외부 Aurora PostgreSQL
postgresql:
  enabled: false
externalDatabase:
  host: "harbor-aurora.cluster-xxxx.ap-northeast-2.rds.amazonaws.com"
  port: 5432
  user: "harbor"
  coreDatabase: "registry"
  sslmode: "require"

# 외부 ElastiCache Redis
redis:
  enabled: false
externalRedis:
  host: "harbor-redis.xxxx.clustercfg.apn2.cache.amazonaws.com"
  port: 6379
  coreDatabaseIndex: "0"
  jobserviceDatabaseIndex: "1"
  registryDatabaseIndex: "2"
```

```bash
helm upgrade --install harbor bitnami/harbor \
  -n harbor --create-namespace \
  -f values-ha.yaml \
  --set core.existingSecret=harbor-core-secret \
  --set externalDatabase.existingSecret=harbor-db-secret \
  --wait
```

---

## 6. 이미지 백업 전략

### 6.1 백업 레이어 구조 (공통)

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 1: Object Storage 자체 이중화 (실시간)                 │
│  Ceph ERASURE / MinIO Distributed / S3 Multi-AZ             │
│  RPO: 0  RTO: 즉시 (스토리지 내부 복구)                      │
├──────────────────────────────────────────────────────────────┤
│  Layer 2: Harbor Replication → DR 사이트 (준실시간)           │
│  Primary Harbor ──Push Replication──▶ DR Harbor             │
│  RPO: Replication 주기  RTO: ~30분                           │
├──────────────────────────────────────────────────────────────┤
│  Layer 3: 스토리지 정기 스냅샷 / 원격 복제 (일 1회)          │
│  MinIO → rclone → 원격지 / S3 → Cross-Region Replication    │
│  RPO: 24시간  RTO: 수시간                                    │
├──────────────────────────────────────────────────────────────┤
│  Layer 4: DB 백업 (일 1회)                                   │
│  pg_dump → 압축 → 원격 스토리지 (30일 보존)                  │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 Layer 1 — 온프레미스: MinIO 데이터 백업 (rclone)

```bash
# rclone 설치 및 설정
curl https://rclone.org/install.sh | bash

# ~/.config/rclone/rclone.conf
[minio-primary]
type = s3
provider = Minio
endpoint = http://10.0.0.40:9000
access_key_id = minioadmin
secret_access_key = <PASSWORD>

[minio-dr]
type = s3
provider = Minio
endpoint = http://dr-site.internal:9000
access_key_id = minioadmin
secret_access_key = <DR_PASSWORD>

# 동기화 (crontab에 등록)
rclone sync minio-primary:harbor-registry minio-dr:harbor-registry \
  --transfers 8 \
  --checkers 16 \
  --log-file /var/log/rclone-harbor.log \
  --log-level INFO
```

```bash
# crontab -e (매일 새벽 2시 동기화)
0 2 * * * /usr/bin/rclone sync minio-primary:harbor-registry minio-dr:harbor-registry \
  --transfers 8 --log-file /var/log/rclone-harbor.log >> /var/log/rclone-harbor-cron.log 2>&1
```

### 6.3 Layer 1 — AWS: S3 Cross-Region Replication

```bash
# DR 버킷 생성 (us-east-1)
aws s3api create-bucket --bucket harbor-registry-dr --region us-east-1
aws s3api put-bucket-versioning \
  --bucket harbor-registry-dr \
  --versioning-configuration Status=Enabled \
  --region us-east-1

# CRR 설정
cat > crr-config.json << 'EOF'
{
  "Role": "arn:aws:iam::<ACCOUNT_ID>:role/HarborS3ReplicationRole",
  "Rules": [{
    "ID": "HarborCRR",
    "Status": "Enabled",
    "Filter": {"Prefix": "registry/"},
    "Destination": {
      "Bucket": "arn:aws:s3:::harbor-registry-dr",
      "StorageClass": "STANDARD_IA"
    }
  }]
}
EOF

aws s3api put-bucket-replication \
  --bucket harbor-registry-prod \
  --replication-configuration file://crr-config.json
```

### 6.4 Layer 2 — Harbor Replication Policy (공통)

```bash
# DR Harbor endpoint 등록
curl -u admin:<PW> \
  -X POST https://harbor.example.com/api/v2.0/registries \
  -H "Content-Type: application/json" \
  -d '{
    "name": "harbor-dr",
    "type": "harbor",
    "url": "https://harbor-dr.example.com",
    "credential": {
      "access_key": "admin",
      "access_secret": "<DR_PW>",
      "type": "basic"
    },
    "insecure": false
  }'

# 이벤트 기반 Push Replication 정책 생성 (push 즉시 복제)
curl -u admin:<PW> \
  -X POST https://harbor.example.com/api/v2.0/replication/policies \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dr-full-replication",
    "dest_registry": {"id": 1},
    "filters": [],
    "trigger": {"type": "event_based", "trigger_settings": {}},
    "deletion": false,
    "override": true,
    "enabled": true
  }'
```

### 6.5 Layer 4 — DB 백업 (공통)

```bash
# 온프레미스: cron으로 pg_dump 실행
cat > /opt/scripts/harbor-db-backup.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/data/harbor-backups/db
KEEP_DAYS=30

mkdir -p $BACKUP_DIR

PGPASSWORD=<PASSWORD> pg_dump \
  -h 10.0.0.20 -U harbor -d registry \
  | gzip > ${BACKUP_DIR}/harbor-db-${TIMESTAMP}.sql.gz

# 오래된 백업 정리
find $BACKUP_DIR -name "*.sql.gz" -mtime +${KEEP_DAYS} -delete

echo "[$(date)] Backup completed: harbor-db-${TIMESTAMP}.sql.gz"
EOF

chmod +x /opt/scripts/harbor-db-backup.sh

# crontab -e (매일 새벽 1시)
0 1 * * * /opt/scripts/harbor-db-backup.sh >> /var/log/harbor-db-backup.log 2>&1
```

---

## 7. 운영 고려사항

### 스토리지 선택 기준

| 기준 | NFS | MinIO | Ceph RGW | AWS S3 |
|---|---|---|---|---|
| 구성 난이도 | 쉬움 | 보통 | 어려움 | 쉬움 |
| 확장성 | 낮음 | 높음 | 매우 높음 | 무제한 |
| 이중화 | 수동 | 내장 (Erasure Coding) | 내장 (RADOS) | 내장 (Multi-AZ) |
| 권장 규모 | <1TB | 1~50TB | 50TB+ | 제한 없음 |
| 비용 | 하드웨어만 | 하드웨어만 | 하드웨어 + 운영 | 사용량 과금 |

### 용량 계획

| 규모 | Harbor 인스턴스 | DB | Redis | 스토리지 |
|---|---|---|---|---|
| 소 (<1TB, 팀 단위) | VM 2대, 4코어/8GB | 단일 PG or RDS t3.medium | 단일 Redis | NFS or MinIO 2노드 |
| 중 (1~10TB, 부서 단위) | VM 2대 or K8s 3 replica | PG Patroni HA or Aurora | Redis Sentinel | MinIO 4노드 or S3 |
| 대 (10TB+, 기업 전체) | K8s 5+ replica + HPA | Aurora r6g.2xlarge | ElastiCache Cluster | Ceph or S3 |

### 모니터링 핵심 지표

```bash
# Harbor 헬스 체크 (모든 구성 공통)
curl -u admin:<PW> https://harbor.example.com/api/v2.0/health | jq .

# 각 컴포넌트 상태 확인
# "status": "healthy" 가 전체 컴포넌트에서 나와야 정상

# 온프레미스 — MinIO 상태
curl http://10.0.0.40:9000/minio/health/cluster

# Docker Compose 방식 — 각 VM에서
docker compose -f /opt/harbor/docker-compose.yml ps

# Prometheus 지표 (Harbor /metrics 엔드포인트)
# harbor_core_http_request_duration_seconds  → API 응답 시간
# harbor_jobservice_task_queue_size          → 비동기 작업 적체
```

---

## 8. 트러블슈팅

### Harbor VM 1대 장애 시 동작

**현상**: Harbor VM1 다운 → 클라이언트는 정상 동작

**이유**: Nginx/HAProxy가 health check로 VM1을 자동 제외, VM2로만 라우팅

```bash
# Nginx health check 설정 추가 (upstream에 추가)
upstream harbor_https {
    least_conn;
    server 10.0.0.11:443;
    server 10.0.0.12:443;
    # check interval=3000ms 등은 nginx_upstream_check_module 필요
}
```

### docker push 중 연결 끊김 (대용량 이미지)

**원인**: Nginx proxy_timeout 기본값(60s)보다 업로드 시간이 긴 경우

**해결**:
```nginx
# stream 블록 (TCP 프록시)
server {
    listen 443;
    proxy_pass harbor_https;
    proxy_timeout 600s;          # 10분으로 연장
    proxy_connect_timeout 10s;
}
```

### MinIO 드라이브 1개 장애

**현상**: MinIO 클러스터 계속 동작, 장애 드라이브만 복구 필요

```bash
# MinIO 클러스터 상태 확인
docker run --rm quay.io/minio/mc admin info local

# 드라이브 교체 후 힐링
docker run --rm quay.io/minio/mc admin heal local/harbor-registry --recursive
```

### Harbor VM 2대 모두 재시작 후 동기화 문제

**현인**: Redis 세션 TTL 만료 전 재시작으로 캐시 불일치

**해결**:
```bash
# 한 번에 하나씩 재시작 (Rolling Restart)
# VM1 docker compose 재시작 → 헬스 체크 통과 확인 후 VM2 재시작
docker compose restart
curl -k https://localhost/api/v2.0/health  # healthy 확인 후
# VM2에서 동일 작업
```

---

## 9. 구현 체크리스트

### 공통 (방식 무관)
- [ ] PostgreSQL HA 구성 완료 (Patroni or Aurora)
- [ ] Redis HA 구성 완료 (Sentinel or ElastiCache)
- [ ] Harbor 설정에 외부 DB/Redis 연결 확인
- [ ] `/api/v2.0/health` 모든 컴포넌트 healthy
- [ ] Harbor Replication → DR 사이트 구성
- [ ] DB pg_dump 정기 백업 스크립트 등록 및 테스트

### Docker Compose + VM (방식 A)
- [ ] Nginx + Keepalived VIP 구성 완료
- [ ] Harbor VM 2대 동일 harbor.yml 설정
- [ ] 스토리지 선택 및 구성 (MinIO / Ceph / NFS)
- [ ] rclone DR 동기화 cron 등록
- [ ] LB VM 장애 시 VIP 이전 테스트

### K8s / EKS (방식 B)
- [ ] Pod Anti-Affinity 멀티 AZ 분산 확인
- [ ] HPA 설정 완료
- [ ] IRSA 역할 적용 및 S3 접근 테스트
- [ ] S3 Cross-Region Replication 설정
- [ ] S3 VPC Gateway Endpoint 생성

### 복구 검증 (필수)
- [ ] Harbor VM 1대 강제 종료 → 서비스 무중단 확인
- [ ] DR Harbor에서 이미지 Pull 성공 확인
- [ ] DB 스냅샷에서 복구 테스트
- [ ] 스토리지 장애 시뮬레이션 (MinIO 드라이브 1개 오프라인)
