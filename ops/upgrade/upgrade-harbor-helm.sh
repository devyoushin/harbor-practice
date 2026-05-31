#!/usr/bin/env bash
set -euo pipefail

HARBOR_NAMESPACE="${HARBOR_NAMESPACE:-harbor}"
RELEASE="${RELEASE:-harbor}"
VALUES_FILE="${VALUES_FILE:-$(dirname "$0")/../values/values-minimal.yaml}"

echo "Backup PostgreSQL before major upgrade."
helm get values "${RELEASE}" -n "${HARBOR_NAMESPACE}" -o yaml > "harbor-values-before-upgrade.yaml"

helm repo update bitnami
helm upgrade "${RELEASE}" bitnami/harbor \
  --namespace "${HARBOR_NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 20m

kubectl rollout status statefulset/"${RELEASE}"-postgresql -n "${HARBOR_NAMESPACE}" || true
kubectl get pods -n "${HARBOR_NAMESPACE}"
