# shellcheck shell=bash

soviez_migration_freeze_state_path() {
  local op_id="$1"
  printf '%s/freeze.json\n' "$(soviez_migration_freeze_dir "$op_id")"
}

soviez_migration_freeze_start() {
  local pair_id="$1" op_id="$2"
  local timeout="${SOVIEZ_MIG_FREEZE_TIMEOUT_SECONDS:-900}"
  local dir path started production_id=""
  local guard_json=""
  soviez_migration_paths_init
  if declare -F soviez_phase19_assert_cert_gates >/dev/null 2>&1; then
    soviez_phase19_assert_cert_gates
  fi
  if [[ "${SOVIEZ_MIG_FREEZE_FIXTURE:-0}" == "1" ]] && \
     { [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]] || [[ "${SOVIEZ_PHASE19_REQUIRE_REAL_ERP_STAGING:-0}" == "1" ]]; }; then
    # Certification forbids marker-only fixture freeze
    if [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]]; then
      soviez_migration_die MIGRATION_SOURCE_FREEZE_FAILED "fixture freeze forbidden in certification mode"
    fi
  fi
  dir="$(soviez_migration_freeze_dir "$op_id")"
  mkdir -p "$dir"
  path="$(soviez_migration_freeze_state_path "$op_id")"
  started="$(soviez_migration_now_iso)"
  production_id="$(soviez_json_get "$(soviez_migration_transfer_load_pair "$pair_id" 2>/dev/null || echo '{}')" source_production_id 2>/dev/null || true)"
  local mode="application_write_guard"
  local marker="$dir/WRITE_FREEZE.active"
  if [[ "${SOVIEZ_MIG_FREEZE_FIXTURE:-0}" == "1" ]]; then
    mode="fixture_state_file"
  fi

  # Start write-guard BEFORE activating marker so probe endpoint is ready
  if [[ "$mode" != "fixture_state_file" ]] && declare -F soviez_migration_freeze_guard_start >/dev/null 2>&1; then
    guard_json="$(soviez_migration_freeze_guard_start "$pair_id" "$op_id" "$production_id")" || \
      soviez_migration_die MIGRATION_SOURCE_FREEZE_FAILED "write-guard start failed"
  fi

  printf 'operation_id=%s\npair_id=%s\nproduction_id=%s\nreason=migration_final_sync\nexpires_timeout=%s\n' \
    "$op_id" "$pair_id" "${production_id:-}" "$timeout" > "$marker"
  chmod 600 "$marker" 2>/dev/null || true

  if [[ -n "${SOVIEZ_MIG_FREEZE_HTTP_STATUS_PATH:-}" ]]; then
    mkdir -p "$(dirname "$SOVIEZ_MIG_FREEZE_HTTP_STATUS_PATH")"
    printf '503\nWrite freeze active for migration operation %s\n' "$op_id" \
      > "$SOVIEZ_MIG_FREEZE_HTTP_STATUS_PATH"
  fi

  SOVIEZ_PAIR="$pair_id" SOVIEZ_OP="$op_id" SOVIEZ_T="$timeout" SOVIEZ_S="$started" \
    SOVIEZ_OUT="$path" SOVIEZ_MODE="$mode" SOVIEZ_MARKER="$marker" \
    SOVIEZ_PROD="${production_id:-}" SOVIEZ_GUARD="${guard_json:-}" python3 - <<'PY'
import json, os, datetime
guard={}
try:
  guard=json.loads(os.environ.get("SOVIEZ_GUARD") or "{}")
except Exception:
  guard={}
doc={
  "schema_version":"soviez.migration_source_freeze.v1",
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "source_production_id": os.environ.get("SOVIEZ_PROD") or "",
  "state": "frozen",
  "mode": os.environ["SOVIEZ_MODE"],
  "marker_path": os.environ["SOVIEZ_MARKER"],
  "write_guard": guard,
  "services_stopped": False,
  "postgresql_stopped": False,
  "license_mutated": False,
  "dns_mutated": False,
  "timeout_seconds": int(os.environ["SOVIEZ_T"]),
  "started_at": os.environ["SOVIEZ_S"],
  "expires_at": (datetime.datetime.utcnow()+datetime.timedelta(seconds=int(os.environ["SOVIEZ_T"]))).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "released": False,
  "source_write_freeze": True,
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(doc, separators=(",", ":")))
print(json.dumps(doc, separators=(",", ":")))
PY

  local wd="${SOVIEZ_MIG_FREEZE_WATCHDOG:-}"
  if [[ -z "$wd" ]]; then
    if [[ "${SOVIEZ_MIG_FREEZE_FIXTURE:-0}" == "1" ]]; then
      wd=0
    elif [[ "${SOVIEZ_PHASE19_CERTIFICATION:-0}" == "1" ]]; then
      wd=1
    elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      wd=0
    else
      wd=1
    fi
  fi
  if [[ "$wd" == "1" ]] && declare -F soviez_migration_freeze_watchdog_standalone >/dev/null 2>&1; then
    soviez_migration_freeze_watchdog_standalone "$pair_id" "$op_id" "$timeout"
  elif [[ "$wd" == "1" ]]; then
    (
      sleep "$timeout"
      if [[ -f "$path" ]]; then
        rel="$(soviez_json_get "$(cat "$path")" released 2>/dev/null || echo false)"
        if [[ "$rel" != "true" && "$rel" != "True" ]]; then
          touch "$dir/timed_out"
          soviez_migration_freeze_release "$pair_id" "$op_id" "timeout" || true
          printf '%s\n' "MIGRATION_SOURCE_FREEZE_TIMEOUT" > "$dir/failure_code"
        fi
      fi
    ) &
    echo $! > "$dir/watchdog.pid"
  fi
  return 0
}

soviez_migration_freeze_release() {
  local pair_id="$1" op_id="$2" reason="${3:-released}"
  local path dir ended marker
  soviez_migration_paths_init
  dir="$(soviez_migration_freeze_dir "$op_id")"
  path="$(soviez_migration_freeze_state_path "$op_id")"
  marker="$dir/WRITE_FREEZE.active"
  mkdir -p "$dir"
  ended="$(soviez_migration_now_iso)"
  rm -f "$marker"
  if declare -F soviez_migration_freeze_guard_stop >/dev/null 2>&1; then
    # Keep guard process for post-release write proof when SOVIEZ_MIG_FREEZE_KEEP_GUARD=1
    if [[ "${SOVIEZ_MIG_FREEZE_KEEP_GUARD:-0}" != "1" ]]; then
      soviez_migration_freeze_guard_stop "$op_id" || true
    fi
  fi
  if [[ -n "${SOVIEZ_MIG_FREEZE_HTTP_STATUS_PATH:-}" ]]; then
    rm -f "$SOVIEZ_MIG_FREEZE_HTTP_STATUS_PATH"
  fi
  if [[ -f "$dir/watchdog.pid" ]]; then
    kill "$(cat "$dir/watchdog.pid" 2>/dev/null)" 2>/dev/null || true
    rm -f "$dir/watchdog.pid"
  fi
  if [[ ! -f "$path" ]]; then
    printf '{"state":"released","released":true,"reason":"%s","idempotent":true,"source_write_freeze":false}\n' "$reason" > "$path"
    cat "$path"
    return 0
  fi
  SOVIEZ_P="$path" SOVIEZ_R="$reason" SOVIEZ_E="$ended" python3 - <<'PY'
import json, os
from datetime import datetime as dt
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["state"]="released"
d["released"]=True
d["source_write_freeze"]=False
d["release_reason"]=os.environ["SOVIEZ_R"]
d["ended_at"]=os.environ["SOVIEZ_E"]
try:
  s=dt.strptime(d.get("started_at",""), "%Y-%m-%dT%H:%M:%SZ")
  e=dt.strptime(os.environ["SOVIEZ_E"], "%Y-%m-%dT%H:%M:%SZ")
  d["duration_seconds"]=int((e-s).total_seconds())
except Exception:
  d["duration_seconds"]=None
open(p,"w").write(json.dumps(d, separators=(",", ":")))
print(json.dumps(d, separators=(",", ":")))
PY
}

soviez_migration_freeze_reconcile() {
  local pair_id="$1" op_id="$2"
  local path
  path="$(soviez_migration_freeze_state_path "$op_id")"
  if [[ ! -f "$path" ]]; then
    printf '{"state":"absent","source_write_freeze":false}\n'
    return 0
  fi
  local released expires
  released="$(soviez_json_get "$(cat "$path")" released)"
  if [[ "$released" == "true" || "$released" == "True" ]]; then
    cat "$path"
    return 0
  fi
  expires="$(soviez_json_get "$(cat "$path")" expires_at)"
  if soviez_migration_is_expired "$expires"; then
    touch "$(soviez_migration_freeze_dir "$op_id")/timed_out"
    soviez_migration_freeze_release "$pair_id" "$op_id" "reboot_reconcile_timeout"
    return 0
  fi
  if [[ "${SOVIEZ_MIG_FREEZE_KEEP:-0}" != "1" ]]; then
    soviez_migration_freeze_release "$pair_id" "$op_id" "reboot_reconcile"
  else
    cat "$path"
  fi
}
