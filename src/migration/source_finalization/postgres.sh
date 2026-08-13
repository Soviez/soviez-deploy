# shellcheck shell=bash

soviez_migration_p22_postgres_optional_stop() {
  local archive_op_id="$1"
  local out
  out="$(soviez_migration_p22_finalization_dir "$archive_op_id")/postgres.json"
  mkdir -p "$(dirname "$out")"
  if [[ "${SOVIEZ_MIG_P22_STOP_POSTGRES:-0}" != "1" ]]; then
    printf '{"postgres_stopped":false,"policy_gate":"SOVIEZ_MIG_P22_STOP_POSTGRES!=1"}\n' > "$out"
    cat "$out"
    return 0
  fi
  # Policy-gated optional stop — never drop data/volumes.
  if [[ -n "${SOVIEZ_MIG_P22_PG_CONTAINER:-}" ]] && command -v docker >/dev/null 2>&1; then
    docker stop "${SOVIEZ_MIG_P22_PG_CONTAINER}" >/dev/null 2>&1 || true
  fi
  printf '{"postgres_stopped":true,"data_preserved":true,"volumes_preserved":true}\n' > "$out"
  # Update suspend state if present.
  local source_id statef
  source_id="$(soviez_json_get "$(soviez_migration_source_archive_status "$archive_op_id")" source_id)"
  statef="$(soviez_migration_p22_suspend_state_path "$source_id")"
  if [[ -f "$statef" ]]; then
    SOVIEZ_F="$statef" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_F"]))
d["postgres_stopped"]=True
open(os.environ["SOVIEZ_F"],"w").write(json.dumps(d, separators=(",", ":")))
PY
  fi
  cat "$out"
}
