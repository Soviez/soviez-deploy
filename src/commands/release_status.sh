# shellcheck shell=bash

soviez_cmd_release_status_run() {
  local env_id="${SOVIEZ_CLI_TARGET:-${1:-}}"
  [[ -n "$env_id" ]] || {
    echo "usage: soviez.sh --release-status <environment-id>" >&2
    return 1
  }

  local identity="${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}/${env_id}/identity.json"
  [[ -f "$identity" ]] || {
    echo "[error] environment not found: $env_id" >&2
    return 1
  }

  echo "=== Release status: $env_id ==="
  python3 - "$identity" <<'PY'
import json, sys
ident = json.load(open(sys.argv[1], encoding="utf-8"))
fields = [
    ("Environment", ident.get("tenant_id") or ident.get("production_id") or "?"),
    ("Installed ERP release", ident.get("release_name") or ident.get("release_id") or "unknown"),
    ("Installed image digest", ident.get("image_digest") or ident.get("digest") or "unknown"),
    ("Platform version", ident.get("platform_version") or "unknown"),
]
for k, v in fields:
    print(f"{k}: {v}")
PY

  local catalog stable
  catalog="$(soviez_release_catalog_load 2>/dev/null || echo '{}')"
  stable="$(python3 -c 'import json,sys; c=json.loads(sys.argv[1]); print(c.get("channels",{}).get("stable") or "none")' "$catalog" 2>/dev/null || echo none)"
  echo "Current stable release: $stable"
  echo "Technical Support: ${SOVIEZ_SUPPORT_STATE:-unknown}"
  echo "Product Updates: ${SOVIEZ_PRODUCT_UPDATES_STATE:-unknown}"
  return 0
}
