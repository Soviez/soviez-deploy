# shellcheck shell=bash
# Phase 21 cutover plan — signed, read-only intent document. Does not mutate
# DNS, routing, or traffic ownership.

soviez_migration_cutover_plan() {
  local pair_id="${1:-}"
  [[ -n "$pair_id" ]] || soviez_migration_die MIGRATION_PAIR_REQUIRED "pair-id required"
  soviez_migration_assert_phase21_cutover_allowed "$SOVIEZ_MIG_OP_CUTOVER_PLAN"
  soviez_migration_cutover_paths_init

  local reval auth_id license_id
  reval="$(soviez_migration_p21_revalidate_phase20 "$pair_id")"
  auth_id="$(soviez_json_get "$reval" authorization_id)"
  license_id="$(soviez_json_get "$reval" license_id)"

  local fqdn="${SOVIEZ_MIG_P21_FQDN:-prod.example.test}"
  local dest_ip="${SOVIEZ_MIG_P21_DEST_IP:-127.0.0.1}"
  local src_dns=""
  if declare -F soviez_migration_dns_authoritative_lookup >/dev/null 2>&1; then
    src_dns="$(soviez_migration_dns_authoritative_lookup "$fqdn" A 2>/dev/null | tr '\n' ',' || true)"
  fi

  local plan_id dir
  plan_id="$(soviez_migration_new_id cplan)"
  dir="$(soviez_migration_cutover_plan_dir "$plan_id")"
  mkdir -p "$dir"

  SOVIEZ_OUT="$dir/plan.json" SOVIEZ_PLAN="$plan_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_AUTH="$auth_id" \
    SOVIEZ_LIC="$license_id" SOVIEZ_FQDN="$fqdn" SOVIEZ_SRC_DNS="$src_dns" SOVIEZ_DST_IP="$dest_ip" \
    SOVIEZ_WINDOW="${SOVIEZ_MIG_P21_ROLLBACK_WINDOW_SECONDS:-1800}" \
    SOVIEZ_FREEZE_MAX="${SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS:-900}" python3 - <<'PY'
import json, os, time
body = {
  "schema": "soviez.migration_cutover_plan.v1",
  "plan_id": os.environ["SOVIEZ_PLAN"],
  "pair_id": os.environ["SOVIEZ_PAIR"],
  "authorization_id": os.environ["SOVIEZ_AUTH"],
  "license_id": os.environ["SOVIEZ_LIC"],
  "production_fqdn": os.environ["SOVIEZ_FQDN"],
  "source_dns_snapshot": os.environ.get("SOVIEZ_SRC_DNS", ""),
  "destination_target": os.environ.get("SOVIEZ_DST_IP", ""),
  "rollback_window_seconds": int(os.environ["SOVIEZ_WINDOW"]),
  "freeze_max_seconds": int(os.environ["SOVIEZ_FREEZE_MAX"]),
  "status": "planned",
  "traffic_owner": "source",
  "production_dns_changed": False,
  "traffic_cutover_started": False,
  "phase21_allowed": False,
  "phase22_allowed": False,
  "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$dir/plan.json"
  cat "$dir/plan.json"
}

soviez_migration_cutover_plan_show() {
  local plan_id="${1:-}"
  [[ -n "$plan_id" ]] || soviez_migration_die MIGRATION_CUTOVER_PLAN_REQUIRED "plan-id required"
  soviez_migration_cutover_paths_init
  local f
  f="$(soviez_migration_cutover_plan_dir "$plan_id")/plan.json"
  [[ -f "$f" ]] || soviez_migration_die MIGRATION_CUTOVER_PLAN_INVALID "cutover plan not found"
  soviez_migration_verify_object_signature "$f" || \
    soviez_migration_die MIGRATION_CUTOVER_PLAN_INVALID "cutover plan signature invalid"
  cat "$f"
}
