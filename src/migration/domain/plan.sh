# shellcheck shell=bash

soviez_migration_domain_plan_build() {
  local pair_id="$1" pair_json="$2" migration_fqdn="$3" production_fqdn="$4" inspection_json="$5"
  local plan_id op_id expires flags
  plan_id="$(soviez_migration_new_id dplan)"
  op_id="$(soviez_migration_new_id dom-op)"
  expires="$(soviez_migration_expires_iso "${SOVIEZ_MIG_ROUTING_PLAN_TTL_SECONDS:-86400}")"
  flags="$(soviez_migration_domain_plan_flags_json "$pair_json")"
  SOVIEZ_PID="$plan_id" SOVIEZ_OP="$op_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_PJ="$pair_json" \
    SOVIEZ_MF="$migration_fqdn" SOVIEZ_PF="$production_fqdn" SOVIEZ_IN="$inspection_json" \
    SOVIEZ_FL="$flags" SOVIEZ_E="$expires" python3 - <<'PY'
import json, os, datetime
pair=json.loads(os.environ["SOVIEZ_PJ"])
flags=json.loads(os.environ["SOVIEZ_FL"])
ins=json.loads(os.environ["SOVIEZ_IN"])
print(json.dumps({
  "schema_version": "soviez.migration_domain_plan.v1",
  "plan_id": os.environ["SOVIEZ_PID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "strategy": "option_a_migrate_subdomain",
  "production_fqdn": os.environ["SOVIEZ_PF"],
  "migration_fqdn": os.environ["SOVIEZ_MF"],
  "source_inspection": ins,
  "expected_dns_records": {
    "txt_ownership": {"name": f"_soviez-migration.{os.environ['SOVIEZ_MF']}", "ttl": 300},
    "reachability": {"a_or_aaaa_or_cname": True, "fqdn": os.environ["SOVIEZ_MF"]},
  },
  "authorization_flags": flags,
  "production_domain_mutation_allowed": False,
  "source_maintenance_allowed": False,
  "payload_transfer_allowed": False,
  "migration_token_consumed": False,
  "destination_production_activated": False,
  "source_dns_mutation_allowed": False,
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "expires_at": os.environ["SOVIEZ_E"],
  "status": "planned",
}, separators=(",", ":")))
PY
}
