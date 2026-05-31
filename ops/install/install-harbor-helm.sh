#!/usr/bin/env bash
set -euo pipefail

HARBOR_NAMESPACE="${HARBOR_NAMESPACE:-harbor}"
RELEASE="${RELEASE:-harbor}"
VALUES_FILE="${VALUES_FILE:-$(dirname "$0")/../values/values-minimal.yaml}"

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami

kubectl create namespace "${HARBOR_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "${RELEASE}" bitnami/harbor \
  --namespace "${HARBOR_NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 15m

kubectl get pods -n "${HARBOR_NAMESPACE}"
helm status "${RELEASE}" -n "${HARBOR_NAMESPACE}"
