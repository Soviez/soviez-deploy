# shellcheck shell=bash

soviez_migration_domain_schema_version() {
  printf 'soviez.migration_domain_plan.v1\n'
}

soviez_migration_domain_plan_flags_json() {
  SOVIEZ_PAIR="${1:-{}}" python3 - <<'PY'
import json, os
print(json.dumps({
  "production_domain_mutation_allowed": False,
  "source_maintenance_allowed": False,
  "payload_transfer_allowed": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "source_dns_mutation_allowed": False,
  "production_tls_preissue_allowed": False,
  "cutover_authorized": False,
}, separators=(",", ":")))
PY
}
