#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

start_mock() {
  SOVIEZ_MOCK_PORT="${SOVIEZ_MOCK_PORT:-0}"
  if [[ "$SOVIEZ_MOCK_PORT" == "0" ]]; then
    SOVIEZ_MOCK_PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"
  fi
  export SOVIEZ_MOCK_PORT
  SOVIEZ_MOCK_HOST="${SOVIEZ_MOCK_HOST:-127.0.0.1}"
  SOVIEZ_MOCK_PID=""
  SOVIEZ_MOCK_HOST="$SOVIEZ_MOCK_HOST" SOVIEZ_MOCK_PORT="$SOVIEZ_MOCK_PORT" \
    python3 "$ROOT/tests/integration/mock_saas_server.py" &
  SOVIEZ_MOCK_PID=$!
  for _ in $(seq 1 50); do
    if curl -sf "http://${SOVIEZ_MOCK_HOST}:${SOVIEZ_MOCK_PORT}/api/installer-auth/device/start" \
      -X POST -d '{"nonce":"ping"}' -H 'Content-Type: application/json' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "mock server failed to start on port $SOVIEZ_MOCK_PORT" >&2
  return 1
}

stop_mock() {
  [[ -n "${SOVIEZ_MOCK_PID:-}" ]] && kill "$SOVIEZ_MOCK_PID" 2>/dev/null || true
  wait "$SOVIEZ_MOCK_PID" 2>/dev/null || true
}

setup_test_env() {
  export SOVIEZ_TEST_MODE=1
  export SOVIEZ_AUTO_CONSENT=1
  export SOVIEZ_ROOT="${SOVIEZ_ROOT:-$(mktemp -d)}"
  export SOVIEZ_SAAS_BASE_URL="http://127.0.0.1:${SOVIEZ_MOCK_PORT}"
  export SOVIEZ_REGISTRY_GATEWAY_URL="$SOVIEZ_SAAS_BASE_URL"
  export SOVIEZ_ODOO_STUB="$ROOT/tests/helpers/odoo_activate_stub.sh"
}
