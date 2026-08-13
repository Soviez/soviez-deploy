# shellcheck shell=bash

soviez_migration_report_sign_and_store() {
  local kind="$1" id="$2" json="$3"
  local dir path
  soviez_migration_paths_init
  case "$kind" in
    discovery) dir="$(soviez_migration_discovery_dir "$id")" ;;
    bootstrap) dir="$(soviez_migration_bootstrap_dir "$id")" ;;
    pair) dir="$(soviez_migration_pair_dir "$id")" ;;
    readiness) dir="$(soviez_migration_readiness_dir "$id")" ;;
    domain_plan) dir="$(soviez_migration_domain_plan_dir "$id")" ;;
    routing) dir="$(soviez_migration_routing_plan_dir "$id")" ;;
    dns_challenge) dir="$(soviez_migration_dns_challenge_dir "$id")" ;;
    *) dir="$SOVIEZ_MIG_EVIDENCE_DIR/$id" ;;
  esac
  mkdir -p "$dir"
  path="$dir/object.json"
  soviez_migration_write_json "$path" "$json"
  soviez_migration_sign_object_file "$path"
  cat "$path"
}
