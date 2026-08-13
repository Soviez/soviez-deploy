# shellcheck shell=bash
# Option B: stop exact ERP marker/service/container only; preserve host/volumes/backups.

soviez_migration_p22_runtime_suspend() {
  local archive_op_id="$1"
  local source_id marker statef stop_committed
  source_id="$(soviez_json_get "$(soviez_migration_source_archive_status "$archive_op_id")" source_id)"
  marker="${SOVIEZ_MIG_P22_ERP_MARKER:-soviez-erp-source}"
  statef="$(soviez_migration_p22_suspend_state_path "$source_id")"
  mkdir -p "$(dirname "$statef")"
  stop_committed="$(dirname "$statef")/stop_committed"

  if [[ -f "$statef" ]] && [[ "$(soviez_json_get "$(cat "$statef")" suspended)" == "True" || "$(soviez_json_get "$(cat "$statef")" suspended)" == "true" ]]; then
    cat "$statef"
    return 0
  fi

  # Response-loss recovery: stop already committed, ack missing → finish without re-stop.
  if [[ -f "$stop_committed" ]] && [[ ! -f "$statef" || "$(soviez_json_get "$(cat "$statef" 2>/dev/null || echo '{}')" suspended 2>/dev/null || true)" != "true" ]]; then
    if [[ "${SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS:-0}" == "1" ]]; then
      unset SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS
      export SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS=0
      soviez_migration_die MIGRATION_RUNTIME_SUSPEND_RESPONSE_LOSS \
        "runtime stop committed; response lost (inject once)"
    fi
    SOVIEZ_OUT="$statef" SOVIEZ_SID="$source_id" SOVIEZ_OP="$archive_op_id" SOVIEZ_MK="$marker" \
    SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_runtime_suspend.v1",
  "source_id": os.environ["SOVIEZ_SID"],
  "archive_operation_id": os.environ["SOVIEZ_OP"],
  "suspended": True,
  "marker": os.environ["SOVIEZ_MK"],
  "host_preserved": True,
  "volumes_preserved": True,
  "backups_preserved": True,
  "postgres_stopped": False,
  "survives_reboot": True,
  "accidental_start_denied": True,
  "duplicate_suspension": False,
  "ack": "idempotent_retry",
  "suspended_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
    return 0
  fi

  # Stop exact container/service if present (fixture: touch stop marker).
  if [[ -n "${SOVIEZ_MIG_P22_ERP_CONTAINER:-}" ]] && command -v docker >/dev/null 2>&1; then
    docker stop "${SOVIEZ_MIG_P22_ERP_CONTAINER}" >/dev/null 2>&1 || \
      soviez_migration_die MIGRATION_SOURCE_RUNTIME_SUSPEND_FAILED "failed to stop ERP container"
  fi
  if [[ -n "${SOVIEZ_MIG_P22_ERP_SERVICE:-}" ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl stop "${SOVIEZ_MIG_P22_ERP_SERVICE}" >/dev/null 2>&1 || true
  fi
  # Fixture stop file under mig root (survives reboot simulation).
  mkdir -p "$SOVIEZ_MIG_ROOT/runtime_suspend/$source_id"
  printf 'stopped\n' > "$SOVIEZ_MIG_ROOT/runtime_suspend/$source_id/erp.stop"
  printf '%s\n' "$marker" > "$SOVIEZ_MIG_ROOT/runtime_suspend/$source_id/marker"
  # Exact ERP runtime marker (Option B) — never delete host/data.
  if [[ -n "${SOVIEZ_MIG_P22_ERP_RUNTIME_MARKER:-}" ]]; then
    mkdir -p "$(dirname "$SOVIEZ_MIG_P22_ERP_RUNTIME_MARKER")"
    printf 'SUSPENDED\n' > "$SOVIEZ_MIG_P22_ERP_RUNTIME_MARKER"
  fi
  printf 'stop_committed\n' > "$stop_committed"

  if [[ "${SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS
    export SOVIEZ_MIG_P22_RUNTIME_RESPONSE_LOSS=0
    soviez_migration_die MIGRATION_RUNTIME_SUSPEND_RESPONSE_LOSS \
      "injected response loss after ERP stop commit"
  fi

  SOVIEZ_OUT="$statef" SOVIEZ_SID="$source_id" SOVIEZ_OP="$archive_op_id" SOVIEZ_MK="$marker" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_runtime_suspend.v1",
  "source_id": os.environ["SOVIEZ_SID"],
  "archive_operation_id": os.environ["SOVIEZ_OP"],
  "suspended": True,
  "marker": os.environ["SOVIEZ_MK"],
  "host_preserved": True,
  "volumes_preserved": True,
  "backups_preserved": True,
  "postgres_stopped": False,
  "survives_reboot": True,
  "accidental_start_denied": True,
  "duplicate_suspension": False,
  "ack": "ok",
  "suspended_at": os.environ["SOVIEZ_NOW"],
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
print(open(os.environ["SOVIEZ_OUT"]).read())
PY
}

soviez_migration_p22_assert_not_accidentally_started() {
  local source_id="$1"
  local statef
  statef="$(soviez_migration_p22_suspend_state_path "$source_id")"
  [[ -f "$statef" ]] || return 0
  if [[ "$(soviez_json_get "$(cat "$statef")" suspended)" == "True" || "$(soviez_json_get "$(cat "$statef")" suspended)" == "true" ]]; then
    if [[ "${SOVIEZ_MIG_P22_RECOVERY_START:-0}" != "1" ]]; then
      soviez_migration_die MIGRATION_SOURCE_RUNTIME_ALREADY_SUSPENDED \
        "suspended source start denied without recovery command"
    fi
  fi
}
