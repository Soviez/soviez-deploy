# shellcheck shell=bash

# Fix inventory to honor SOVIEZ_MIG_SOURCE_DB_NAME and production fixture name
soviez_migration_database_inventory() {
  local pair_id="$1"
  local pair discovery_id discovery
  pair="$(soviez_migration_transfer_load_pair "$pair_id")"
  discovery_id="$(soviez_json_get "$pair" source_discovery_id)"
  if [[ -n "${SOVIEZ_MIG_SOURCE_DB_NAME:-}" ]]; then
    printf '{"database_name":"%s","database_uuid":"%s","size_bytes":0,"version":"16"}\n' \
      "$SOVIEZ_MIG_SOURCE_DB_NAME" "$(soviez_json_get "$pair" source_database_uuid 2>/dev/null || echo '')"
    return 0
  fi
  if [[ -n "$discovery_id" && "$discovery_id" != "null" && -f "$(soviez_migration_discovery_dir "$discovery_id")/object.json" ]]; then
    discovery="$(cat "$(soviez_migration_discovery_dir "$discovery_id")/object.json")"
    SOVIEZ_D="$discovery" SOVIEZ_P="$pair" python3 - <<'PY'
import json, os
d=json.loads(os.environ["SOVIEZ_D"]); p=json.loads(os.environ["SOVIEZ_P"])
db=(d.get("database") or {})
ident=(d.get("identity") or {})
prod=(ident.get("production") or ident.get("host_identity") or {})
name=db.get("name") or db.get("database_name") or prod.get("database_name") or "soviez"
print(json.dumps({
  "database_name": name,
  "database_uuid": db.get("uuid") or p.get("source_database_uuid") or "",
  "size_bytes": int((d.get("capacity") or {}).get("database_bytes") or db.get("size_bytes") or 0),
  "version": db.get("version") or "16",
}, separators=(",", ":")))
PY
  else
    printf '{"database_name":"soviez","database_uuid":"","size_bytes":0,"version":"16"}\n'
  fi
}
