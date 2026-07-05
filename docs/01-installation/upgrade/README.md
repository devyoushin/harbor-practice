# Harbor 업그레이드 가이드

Harbor 업그레이드는 Helm release와 내부 PostgreSQL schema migration이 함께 진행될 수 있습니다. 메이저 버전 변경 전에는 values, 데이터베이스, 이미지 스토리지 상태를 반드시 백업합니다.

## 1. 사전 점검

```bash
export HARBOR_NAMESPACE="harbor"
export RELEASE="harbor"
export VALUES_FILE="ops/values/values-minimal.yaml"

helm status ${RELEASE} -n ${HARBOR_NAMESPACE}
helm history ${RELEASE} -n ${HARBOR_NAMESPACE}
helm get values ${RELEASE} -n ${HARBOR_NAMESPACE} -o yaml > harbor-values-before-upgrade.yaml
kubectl get pods,pvc,ingress -n ${HARBOR_NAMESPACE}
```

운영 환경에서는 PostgreSQL 백업과 registry storage 백업 또는 스냅샷을 먼저 완료합니다.

## 2. Helm 업그레이드

이 저장소의 실행 스크립트를 사용합니다.

```bash
HARBOR_NAMESPACE=${HARBOR_NAMESPACE} \
RELEASE=${RELEASE} \
VALUES_FILE=${VALUES_FILE} \
./ops/upgrade/upgrade-harbor-helm.sh
```

직접 실행하려면 아래 명령을 사용합니다.

```bash
helm repo update bitnami
helm upgrade ${RELEASE} bitnami/harbor \
  --namespace ${HARBOR_NAMESPACE} \
  --values ${VALUES_FILE} \
  --wait \
  --timeout 20m
```

## 3. 확인

```bash
kubectl get pods -n ${HARBOR_NAMESPACE}
kubectl rollout status statefulset/${RELEASE}-postgresql -n ${HARBOR_NAMESPACE}
kubectl get ingress -n ${HARBOR_NAMESPACE}
helm status ${RELEASE} -n ${HARBOR_NAMESPACE}
```

Harbor UI 로그인, `docker login`, 이미지 push/pull, Trivy scan 동작을 확인합니다.

## 4. 롤백

```bash
helm history ${RELEASE} -n ${HARBOR_NAMESPACE}
helm rollback ${RELEASE} <REVISION> -n ${HARBOR_NAMESPACE} --wait
kubectl get pods -n ${HARBOR_NAMESPACE}
```

DB migration이 실행된 뒤에는 Helm rollback만으로 schema가 되돌아가지 않을 수 있습니다. 메이저 업그레이드는 백업에서 복구할 수 있는 절차를 확인한 뒤 진행합니다.

