# shellcheck shell=bash

soviez_migration_domain_plan_run() {
  local pair_id="${1:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local pair production_fqdn migration_fqdn inspection plan_json plan_id op_id
  pair="$(soviez_migration_load_pair "$pair_id")"
  production_fqdn="$(soviez_migration_domain_production_fqdn "$pair")"
  [[ -n "$production_fqdn" ]] || soviez_migration_die MIGRATION_DOMAIN_REQUIRED "Production domain unknown from discovery"

  migration_fqdn="$(soviez_migration_domain_strategy_resolve "$production_fqdn" "${SOVIEZ_MIG_DOMAIN_FQDN:-}")"
  soviez_migration_domain_assert_migration_fqdn "$migration_fqdn" "$production_fqdn"

  inspection="$(soviez_migration_source_inspection_run "$pair")"
  plan_json="$(soviez_migration_domain_plan_build "$pair_id" "$pair" "$migration_fqdn" "$production_fqdn" "$inspection")"
  plan_id="$(soviez_json_get "$plan_json" plan_id)"
  op_id="$(soviez_json_get "$plan_json" operation_id)"

  soviez_migration_report_sign_and_store domain_plan "$plan_id" "$plan_json" >/dev/null
  mkdir -p "$SOVIEZ_MIG_ROOT/ops/$op_id"
  printf '{"operation_id":"%s","operation_type":"%s","current_state":"completed","pair_id":"%s","plan_id":"%s"}\n' \
    "$op_id" "$SOVIEZ_MIG_OP_DOMAIN_PLAN" "$pair_id" "$plan_id" > "$SOVIEZ_MIG_ROOT/ops/$op_id/state.json"

  # Link plan to pair (non-destructive metadata)
  local pair_path
  pair_path="$(soviez_migration_pair_dir "$pair_id")/object.json"
  SOVIEZ_P="$pair_path" SOVIEZ_PL="$plan_id" SOVIEZ_MF="$migration_fqdn" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["domain_plan_id"]=os.environ["SOVIEZ_PL"]
d["migration_fqdn"]=os.environ["SOVIEZ_MF"]
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$pair_path"

  cat "$(soviez_migration_domain_plan_dir "$plan_id")/object.json"
}
