#!/usr/bin/env bash
set -euo pipefail

HARBOR_DIR="${HARBOR_DIR:-/opt/harbor}"

cd "${HARBOR_DIR}"
./prepare
./install.sh

docker compose ps
