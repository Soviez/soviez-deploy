# shellcheck shell=bash

soviez_migration_routing_fingerprint_current() {
  local pair_json="$1"
  soviez_migration_source_inspection_run "$pair_json" | \
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("source_routing_fingerprint") or "")'
}

soviez_migration_routing_drift_check() {
  local pair_json="$1" stored_fp="$2"
  local cur
  cur="$(soviez_migration_routing_fingerprint_current "$pair_json")"
  [[ -n "$stored_fp" && "$cur" == "$stored_fp" ]] || \
    soviez_migration_die MIGRATION_SOURCE_ROUTING_CHANGED "Source routing fingerprint drift"
}
