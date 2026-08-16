# shellcheck shell=bash

soviez_cmd_tune_run() {
  local dry="${SOVIEZ_CLI_DRY_RUN:-0}"
  local prod_n=0 stage_n=0
  if declare -F soviez_stage_inventory_list_ids >/dev/null 2>&1; then
    stage_n="$(soviez_stage_inventory_list_ids 2>/dev/null | grep -c . || true)"
  fi
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    prod_n="$(find "${SOVIEZ_ROOT}/tenant" -name identity.json 2>/dev/null | wc -l | tr -d ' ')"
  else
    prod_n="$(find "${SOVIEZ_TENANT_DIR:-/var/soviez/tenant}" -name identity.json 2>/dev/null | wc -l | tr -d ' ')"
  fi
  prod_n="${prod_n:-1}"
  [[ "$prod_n" -ge 1 ]] || prod_n=1

  local profile
  profile="$(soviez_sizing_calculate "$prod_n" "$stage_n" 0 0)"
  echo "=== Soviez sizing plan ==="
  printf '%s\n' "$profile"

  local state_dir
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    state_dir="${SOVIEZ_ROOT}/tuning"
  else
    state_dir="/var/soviez/tuning"
  fi
  mkdir -p "$state_dir"

  # Idempotency: identical effective profile → no apply / no restart.
  if [[ -f "${state_dir}/profile.json" ]]; then
    if SOVIEZ_NEW_PROFILE="$profile" python3 - "$state_dir/profile.json" <<'PY'
import json, os, sys
new=json.loads(os.environ["SOVIEZ_NEW_PROFILE"])
old=json.load(open(sys.argv[1],encoding="utf-8"))
keys=("odoo","postgres","docker","topology")
same=all(old.get(k)==new.get(k) for k in keys)
sys.exit(0 if same else 1)
PY
    then
      echo "[ok] no effective changes (idempotent)"
      return 0
    fi
  fi

  if [[ "$dry" == "1" ]]; then
    echo "[dry-run] proposed changes above; no system state modified"
    echo "[dry-run] restart may be required for: odoo workers/memory, postgres shared_buffers, docker shm"
    return 0
  fi

  # Checkpoint
  if [[ -f "${state_dir}/profile.json" ]]; then
    cp -f "${state_dir}/profile.json" "${state_dir}/profile.prev.json"
  fi
  local conf="${SOVIEZ_TUNE_ODOO_CONF:-}"
  local conf_bak=""
  if [[ -n "$conf" && -f "$conf" ]]; then
    conf_bak="${state_dir}/odoo.conf.bak"
    cp -f "$conf" "$conf_bak"
  fi

  printf '%s\n' "$profile" >"${state_dir}/profile.json.new"
  mv -f "${state_dir}/profile.json.new" "${state_dir}/profile.json"
  printf '%s\n' "$profile" >"${state_dir}/postgres.recommended.json"

  if [[ -n "$conf" && -f "$conf" ]]; then
    local workers soft hard cron
    workers="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["odoo"]["workers"])' <<<"$profile")"
    soft="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["odoo"]["limit_memory_soft"])' <<<"$profile")"
    hard="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["odoo"]["limit_memory_hard"])' <<<"$profile")"
    cron="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["odoo"]["max_cron_threads"])' <<<"$profile")"
    if declare -F soviez_sec__odoo_conf_set_option >/dev/null 2>&1; then
      soviez_sec__odoo_conf_set_option "$conf" workers "$workers" || {
        soviez_cmd_tune_rollback "$state_dir" "$conf" "$conf_bak"
        return 1
      }
      soviez_sec__odoo_conf_set_option "$conf" max_cron_threads "$cron"
      soviez_sec__odoo_conf_set_option "$conf" limit_memory_soft "$soft"
      soviez_sec__odoo_conf_set_option "$conf" limit_memory_hard "$hard"
      soviez_sec__odoo_conf_set_option "$conf" proxy_mode True
      soviez_sec__odoo_conf_set_option "$conf" list_db False
      if [[ "$workers" -gt 0 ]]; then
        soviez_sec__odoo_conf_set_option "$conf" gevent_port 8072
      fi
    fi
    # Verify managed keys present
    if declare -F soviez_ws_assert_odoo_conf >/dev/null 2>&1; then
      if ! soviez_ws_assert_odoo_conf "$conf"; then
        soviez_cmd_tune_rollback "$state_dir" "$conf" "$conf_bak"
        echo "[error] tune verification failed; rolled back" >&2
        return 1
      fi
    fi
  fi

  echo "[ok] tuning profile saved to ${state_dir}/profile.json"
  echo "[ok] apply complete (restart services only if values changed and require it)"
}

soviez_cmd_tune_rollback() {
  local state_dir="$1" conf="${2:-}" conf_bak="${3:-}"
  if [[ -f "${state_dir}/profile.prev.json" ]]; then
    mv -f "${state_dir}/profile.prev.json" "${state_dir}/profile.json"
  fi
  if [[ -n "$conf" && -n "$conf_bak" && -f "$conf_bak" ]]; then
    cp -f "$conf_bak" "$conf"
  fi
  echo "[warn] tune rollback restored previous configuration" >&2
}

soviez_cmd_platform_install_run() {
  soviez_platform_install_self_payload
}
