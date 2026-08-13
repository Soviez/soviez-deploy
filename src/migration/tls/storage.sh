# shellcheck shell=bash

soviez_migration_tls_secrets_dir() {
  local pair_id="$1" fqdn="$2"
  printf '%s/%s/%s\n' "$SOVIEZ_MIG_SECRETS_DIR/tls" "$pair_id" "$fqdn"
}

soviez_migration_tls_inventory_path() {
  local pair_id="$1" fqdn="$2"
  printf '%s/%s.json\n' "$(soviez_migration_tls_dir "$pair_id")" "$fqdn"
}

soviez_migration_tls_write_inventory() {
  local pair_id="$1" fqdn="$2" cert_path="$3" key_path="$4" issuer="$5" not_after="$6"
  mkdir -p "$(soviez_migration_tls_dir "$pair_id")"
  SOVIEZ_PID="$pair_id" SOVIEZ_F="$fqdn" SOVIEZ_C="$cert_path" SOVIEZ_K="$key_path" \
    SOVIEZ_I="$issuer" SOVIEZ_N="$not_after" python3 - <<'PY'
import json, os, datetime
inv={
  "schema_version": "soviez.migration_tls_inventory.v1",
  "pair_id": os.environ["SOVIEZ_PID"],
  "fqdn": os.environ["SOVIEZ_F"],
  "certificate_path": os.environ["SOVIEZ_C"],
  "private_key_path": os.environ["SOVIEZ_K"],
  "issuer": os.environ["SOVIEZ_I"],
  "not_after": os.environ["SOVIEZ_N"],
  "private_key_included": False,
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(os.environ["OUT"], "w").write(json.dumps(inv, separators=(",", ":")))
PY
}
