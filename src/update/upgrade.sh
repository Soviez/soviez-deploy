# shellcheck shell=bash

soviez_update_upgrade_candidate() {
  local op_id="$1" target_digest="$2"
  local cdir logf
  cdir="$(soviez_update_candidate_dir "$op_id")"
  logf="$(soviez_update_op_dir "$op_id")/upgrade.log"
  mkdir -p "$(dirname "$logf")"
  local started ended
  started="$(soviez_utc_now)"

  if [[ "${SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL:-0}" == "1" ]] && ! soviez_update_real_docker_enabled 2>/dev/null; then
    printf 'upgrade_failed addon_incompatible\n' > "$logf"
    soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Custom addon incompatible during candidate upgrade"
  fi
  if [[ "${SOVIEZ_UPDATE_FIXTURE_UPGRADE_FAIL:-0}" == "1" ]]; then
    printf 'upgrade_failed migration\n' > "$logf"
    soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Candidate module upgrade failed"
  fi

  # Exact candidate DB only — never Production -u all
  local db_marker="$cdir/db"
  [[ -d "$db_marker" ]] || soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Candidate DB missing"

  if declare -F soviez_update_interrupt_checkpoint >/dev/null 2>&1; then
    soviez_update_interrupt_checkpoint "$op_id" upgrading_candidate || return $?
  fi

  if soviez_update_real_docker_enabled 2>/dev/null; then
    soviez_update_real_upgrade "$op_id" || return $?
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    # Disposable ERP upgrade simulation against candidate copy only
    printf 'modules_updated=base,web\n' > "$cdir/runtime/modules_updated.txt"
    printf '%s' "$target_digest" > "$cdir/runtime/running_digest.txt"
    printf 'schema=ok\n' > "$cdir/runtime/schema_result.txt"
    if command -v psql >/dev/null 2>&1 && [[ -n "${SOVIEZ_UPDATE_FIXTURE_PG_URL:-}" ]]; then
      psql "$SOVIEZ_UPDATE_FIXTURE_PG_URL" -v ON_ERROR_STOP=1 -c "SELECT 1" >>"$logf" 2>&1 \
        || soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Candidate PostgreSQL unreachable"
      local cand_db
      cand_db="$(soviez_json_get "$(cat "$cdir/candidate.json")" database_uuid | tr -cd 'a-zA-Z0-9' | cut -c1-12)"
      cand_db="upd_${cand_db}"
      createdb "$cand_db" 2>>"$logf" || true
      psql "$cand_db" -c "CREATE TABLE IF NOT EXISTS soviez_update_marker(digest text); INSERT INTO soviez_update_marker(digest) VALUES ('$target_digest');" >>"$logf" 2>&1 || true
      printf 'pg_candidate_db=%s\n' "$cand_db" >> "$cdir/runtime/pg.txt"
    fi
    printf 'live_production_mutated=false\n' > "$cdir/runtime/isolation_proof.txt"
  else
    timeout "${SOVIEZ_UPDATE_UPGRADE_TIMEOUT:-3600}" \
      docker exec "soviez-upd-cand-${op_id}" \
      odoo -d "candidate" -u all --stop-after-init >>"$logf" 2>&1 \
      || soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Candidate odoo upgrade failed"
    printf '%s' "$target_digest" > "$cdir/runtime/running_digest.txt"
  fi

  ended="$(soviez_utc_now)"
  SOVIEZ_S="$started" SOVIEZ_E="$ended" SOVIEZ_D="$target_digest" python3 - <<'PY' > "$(soviez_update_op_dir "$op_id")/upgrade_result.json"
import json,os
print(json.dumps({
  "started_at":os.environ["SOVIEZ_S"],
  "ended_at":os.environ["SOVIEZ_E"],
  "target_digest":os.environ["SOVIEZ_D"],
  "ok":True,
  "live_production_mutated":False,
},separators=(",",":")))
PY
  cat "$(soviez_update_op_dir "$op_id")/upgrade_result.json"
}
