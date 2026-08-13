# shellcheck shell=bash

SOVIEZ_BACKUP_SCHEMA_VERSION="soviez.backup.v1"

soviez_backup_new_id() {
  local hex
  if declare -F soviez_rand_hex >/dev/null 2>&1; then
    hex="$(soviez_rand_hex 6)"
  elif command -v openssl >/dev/null 2>&1; then
    hex="$(openssl rand -hex 6)"
  else
    hex="$(python3 -c 'import secrets; print(secrets.token_hex(6))')"
  fi
  printf 'bk-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || echo 0)" "$hex"
}

soviez_backup_new_op_id() {
  local hex
  if declare -F soviez_rand_hex >/dev/null 2>&1; then
    hex="$(soviez_rand_hex 4)"
  else
    hex="$(openssl rand -hex 4 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(4))')"
  fi
  printf 'bkop-%s-%s\n' "$(date +%Y%m%d%H%M%S 2>/dev/null || echo 0)" "$hex"
}

soviez_backup_write_object() {
  # Args: production_id backup_id json_object
  local prod_id="$1" backup_id="$2" obj="$3"
  local dir file
  soviez_backup_paths_init
  dir="$(soviez_backup_dir "$prod_id" "$backup_id")"
  mkdir -p "$dir"
  chmod 700 "$dir"
  file="$(soviez_backup_object_file "$prod_id" "$backup_id")"
  SOVIEZ_OBJ="$obj" SOVIEZ_SCHEMA="$SOVIEZ_BACKUP_SCHEMA_VERSION" \
  SOVIEZ_BID="$backup_id" SOVIEZ_PID="$prod_id" python3 - <<'PY' > "$file"
import json, os
obj = json.loads(os.environ["SOVIEZ_OBJ"])
obj.setdefault("schema_version", os.environ["SOVIEZ_SCHEMA"])
obj.setdefault("backup_id", os.environ["SOVIEZ_BID"])
obj.setdefault("production_id", os.environ["SOVIEZ_PID"])
print(json.dumps(obj, separators=(",", ":"), sort_keys=True))
PY
  chmod 600 "$file"
  printf '%s' "$(cat "$file")"
}

soviez_backup_read_object() {
  # Args: production_id backup_id  OR  backup_id (lookup via inventory)
  local a="${1:-}" b="${2:-}"
  local file prod_id backup_id
  soviez_backup_paths_init
  if [[ -n "$b" ]]; then
    prod_id="$a"
    backup_id="$b"
  else
    backup_id="$a"
    [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup_id required"
    local idx entry
    idx="$(soviez_backup_inventory_load 2>/dev/null || echo '{"backups":[]}')"
    entry="$(SOVIEZ_IDX="$idx" SOVIEZ_BID="$backup_id" python3 - <<'PY'
import json, os, sys
idx = json.loads(os.environ["SOVIEZ_IDX"])
bid = os.environ["SOVIEZ_BID"]
for b in idx.get("backups", []):
  if b.get("backup_id") == bid:
    print(json.dumps(b, separators=(",", ":")))
    sys.exit(0)
sys.exit(3)
PY
)" || soviez_backup_die BACKUP_NOT_FOUND "Unknown backup: $backup_id"
    prod_id="$(soviez_json_get "$entry" production_id)"
  fi
  file="$(soviez_backup_object_file "$prod_id" "$backup_id")"
  [[ -f "$file" ]] || soviez_backup_die BACKUP_NOT_FOUND "Missing backup object: $backup_id"
  cat "$file"
}

soviez_backup_patch_object() {
  # Args: production_id backup_id patch_json
  local prod_id="$1" backup_id="$2" patch="$3"
  local cur merged
  cur="$(soviez_backup_read_object "$prod_id" "$backup_id")"
  merged="$(SOVIEZ_CUR="$cur" SOVIEZ_PATCH="$patch" python3 - <<'PY'
import json, os
cur = json.loads(os.environ["SOVIEZ_CUR"])
patch = json.loads(os.environ["SOVIEZ_PATCH"])
cur.update(patch)
print(json.dumps(cur, separators=(",", ":"), sort_keys=True))
PY
)"
  soviez_backup_write_object "$prod_id" "$backup_id" "$merged" >/dev/null
  printf '%s' "$merged"
}

soviez_backup_object_skeleton() {
  # Args: backup_id production_id op_id backup_type
  local backup_id="$1" prod_id="$2" op_id="$3" btype="${4:-full}"
  local now
  if declare -F soviez_utc_now >/dev/null 2>&1; then
    now="$(soviez_utc_now)"
  else
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi
  SOVIEZ_BID="$backup_id" SOVIEZ_PID="$prod_id" SOVIEZ_OP="$op_id" \
  SOVIEZ_TYPE="$btype" SOVIEZ_NOW="$now" SOVIEZ_SCHEMA="$SOVIEZ_BACKUP_SCHEMA_VERSION" python3 - <<'PY'
import json, os
print(json.dumps({
  "schema_version": os.environ["SOVIEZ_SCHEMA"],
  "backup_id": os.environ["SOVIEZ_BID"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "backup_type": os.environ["SOVIEZ_TYPE"],
  "production_id": os.environ["SOVIEZ_PID"],
  "license_id": "",
  "database_uuid": "",
  "database_name": "",
  "host_identity": "",
  "runtime_identity": "",
  "erp_major": "",
  "erp_product_version": "",
  "current_image_digest": "",
  "postgresql_version": "",
  "addons_inventory": [],
  "installed_modules": [],
  "configuration_fingerprint": "",
  "created_at": os.environ["SOVIEZ_NOW"],
  "completed_at": "",
  "consistency_method": "quiesce",
  "maintenance_pause_seconds": 0,
  "components": [],
  "checksums": {},
  "encryption": {"enabled": False, "algorithm": "", "key_ref": ""},
  "destination_profile": "",
  "location": "",
  "logical_size_bytes": 0,
  "stored_size_bytes": 0,
  "verification_status": "none",
  "verification_at": "",
  "restore_test_status": "none",
  "restore_test_at": "",
  "retention_class": "",
  "expires_at": "",
  "pinned": False,
  "owner_hold_note": "",
  "parent_backup_id": "",
  "status": "creating",
  "failure_code": "",
  "failure_summary": "",
  "cleanup_state": "none",
  "restore_capable": os.environ["SOVIEZ_TYPE"] == "full",
}, separators=(",", ":")))
PY
}
