# shellcheck shell=bash

soviez_migration_staging_identity_create() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local staging_id pair dir
  soviez_migration_paths_init
  staging_id="$(soviez_migration_new_id staging)"
  pair="$(soviez_migration_transfer_load_pair "$pair_id")"
  dir="$(soviez_migration_staging_dir "$staging_id")"
  mkdir -p "$dir"
  SOVIEZ_SID="$staging_id" SOVIEZ_PAIR="$pair_id" SOVIEZ_OP="$op_id" SOVIEZ_MID="$manifest_id" \
    SOVIEZ_PJ="$pair" SOVIEZ_OUT="$dir/identity.json" python3 - <<'PY'
import json, os, datetime
pair=json.loads(os.environ["SOVIEZ_PJ"])
doc={
  "schema_version":"soviez.migration_staging_identity.v1",
  "staging_id": os.environ["SOVIEZ_SID"],
  "migration_pair_id": os.environ["SOVIEZ_PAIR"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "transfer_manifest_id": os.environ["SOVIEZ_MID"],
  "source_production_id": pair.get("source_production_id") or pair.get("production_id") or "",
  "source_license_id": pair.get("source_license_id") or pair.get("license_id") or "",
  "source_database_uuid": pair.get("source_database_uuid") or "",
  "source_image_digest": pair.get("source_image_digest") or "",
  "destination_host_identity": pair.get("destination_host_fingerprint") or "",
  "destination_bootstrap_id": pair.get("destination_bootstrap_id") or "",
  "non_sellable": True,
  "non_slot_consuming": True,
  "public_routing_enabled": False,
  "production_activated": False,
  "migration_token_consumed": False,
  "migration_token_reserved": False,
  "traffic_cutover_started": False,
  "mail_neutralized": True,
  "cron_neutralized": True,
  "payments_neutralized": True,
  "webhooks_neutralized": True,
  "status": "created",
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(doc, separators=(",", ":")))
print(os.environ["SOVIEZ_SID"])
PY
}
