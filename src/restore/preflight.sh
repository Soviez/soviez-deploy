# shellcheck shell=bash

soviez_restore_preflight() {
  # Args: production_json backup_object_json
  local prod="$1" backup="$2"
  local db_bytes fs_bytes preserve candidate margin required avail

  db_bytes="$(soviez_json_get "$backup" logical_size_bytes 2>/dev/null || echo 0)"
  [[ "$db_bytes" =~ ^[0-9]+$ ]] || db_bytes=0
  if [[ "$db_bytes" -eq 0 ]]; then
    db_bytes="$(soviez_json_get "$prod" database_bytes 2>/dev/null || echo 1048576)"
  fi
  fs_bytes="$(soviez_json_get "$prod" filestore_bytes 2>/dev/null || echo 1048576)"

  # Documented restore contributors + 1.5x staging margin
  preserve=$(( db_bytes + fs_bytes ))
  candidate=$(( db_bytes + fs_bytes ))
  local workspace=$(( 64 * 1024 * 1024 ))
  local components=$(( preserve + candidate + workspace ))
  required=$(( components * 3 / 2 ))
  margin=$(( required - components ))

  avail="$(df -k "${SOVIEZ_RESTORE_CANDIDATES_DIR:-${SOVIEZ_ROOT:-/}}" 2>/dev/null | awk 'NR==2{print $4*1024}' || echo 0)"
  if [[ "${SOVIEZ_RESTORE_FIXTURE_AVAILABLE_BYTES:-}" =~ ^[0-9]+$ ]]; then
    avail="$SOVIEZ_RESTORE_FIXTURE_AVAILABLE_BYTES"
  fi

  SOVIEZ_REQ="$required" SOVIEZ_AVAIL="$avail" SOVIEZ_MARGIN="$margin" \
  SOVIEZ_P="$preserve" SOVIEZ_C="$candidate" python3 - <<'PY'
import json, os
req=int(os.environ["SOVIEZ_REQ"]); avail=int(os.environ["SOVIEZ_AVAIL"])
print(json.dumps({
  "required_bytes": req,
  "available_bytes": avail,
  "safety_margin_bytes": int(os.environ["SOVIEZ_MARGIN"]),
  "staging_margin_factor": "3/2",
  "contributors": [
    {"name": "preserve_current_production", "bytes": int(os.environ["SOVIEZ_P"])},
    {"name": "restore_candidate", "bytes": int(os.environ["SOVIEZ_C"])},
  ],
  "ok": avail >= req,
}, separators=(",", ":")))
PY
}

soviez_restore_preflight_assert() {
  local pf="$1"
  local ok req avail
  ok="$(soviez_json_get "$pf" ok)"
  req="$(soviez_json_get "$pf" required_bytes)"
  avail="$(soviez_json_get "$pf" available_bytes)"
  [[ "$ok" == "True" || "$ok" == "true" ]] \
    || soviez_restore_die RESTORE_CAPACITY_INSUFFICIENT "Need $req bytes, have $avail"
}
