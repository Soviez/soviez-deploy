# shellcheck shell=bash

soviez_cmd_init_run() {
  local marker="/var/soviez/.init-complete"
  if [[ -f "$marker" && "${SOVIEZ_INIT_FORCE:-0}" != "1" ]]; then
    echo "[info] host already initialized; re-running idempotent checks"
  fi
  soviez_host_bootstrap_run || return 1
  date -u +%Y-%m-%dT%H:%M:%SZ >"$marker"
  return 0
}
