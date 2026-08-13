#!/usr/bin/env bash
# Print compose / systemd status helpers
set -euo pipefail

INSTALL_ROOT="${SOVIEZ_RGW_INSTALL_ROOT:-/opt/soviez-registry-gateway}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BIN="docker-compose"
else
  echo "docker compose not found" >&2
  exit 1
fi

cd "${INSTALL_ROOT}"
# shellcheck disable=SC2086
${COMPOSE_BIN} -f compose.yml ps
systemctl --no-pager status soviez-registry-gateway.service || true
