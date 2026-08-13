# shellcheck shell=bash

soviez_backup_inventory_load() {
  local idx
  soviez_backup_paths_init
  idx="$(soviez_backup_inventory_index)"
  if [[ ! -f "$idx" ]]; then
    printf '{"schema_version":"soviez.backup.inventory.v1","backups":[]}\n'
    return 0
  fi
  cat "$idx"
}

soviez_backup_inventory_atomic_write() {
  local content="$1"
  local idx tmp
  soviez_backup_paths_init
  idx="$(soviez_backup_inventory_index)"
  tmp="${idx}.tmp.$$"
  printf '%s\n' "$content" > "$tmp"
  mv -f "$tmp" "$idx"
  chmod 644 "$idx"
}

soviez_backup_inventory_upsert() {
  # Args: backup_object_json (must include backup_id, production_id)
  local obj="$1"
  local idx new_idx
  idx="$(soviez_backup_inventory_load)"
  new_idx="$(SOVIEZ_IDX="$idx" SOVIEZ_OBJ="$obj" python3 - <<'PY'
import json, os
idx = json.loads(os.environ["SOVIEZ_IDX"])
obj = json.loads(os.environ["SOVIEZ_OBJ"])
entry = {
  "backup_id": obj.get("backup_id"),
  "production_id": obj.get("production_id"),
  "backup_type": obj.get("backup_type"),
  "status": obj.get("status"),
  "created_at": obj.get("created_at"),
  "verification_status": obj.get("verification_status", "none"),
  "restore_test_status": obj.get("restore_test_status", "none"),
  "pinned": bool(obj.get("pinned")),
  "restore_capable": bool(obj.get("restore_capable", obj.get("backup_type") == "full")),
  "destination_profile": obj.get("destination_profile", ""),
  "retention_class": obj.get("retention_class", ""),
  "location": obj.get("location", ""),
}
backs = [b for b in idx.get("backups", []) if b.get("backup_id") != entry["backup_id"]]
backs.append(entry)
idx["backups"] = backs
idx["schema_version"] = "soviez.backup.inventory.v1"
print(json.dumps(idx, separators=(",", ":")))
PY
)"
  soviez_backup_inventory_atomic_write "$new_idx"
}

soviez_backup_inventory_list() {
  # Optional filter: production_id
  local prod_filter="${1:-}"
  local idx
  idx="$(soviez_backup_inventory_load)"
  SOVIEZ_IDX="$idx" SOVIEZ_P="$prod_filter" python3 - <<'PY'
import json, os
idx = json.loads(os.environ["SOVIEZ_IDX"])
pf = os.environ.get("SOVIEZ_P") or ""
backs = idx.get("backups", [])
if pf:
  backs = [b for b in backs if b.get("production_id") == pf]
print(json.dumps({"ok": True, "backups": backs}, separators=(",", ":")))
PY
}

soviez_backup_inventory_show() {
  local backup_id="$1"
  [[ -n "$backup_id" ]] || soviez_backup_die BACKUP_NOT_FOUND "backup_id required"
  local obj
  obj="$(soviez_backup_read_object "$backup_id")"
  printf '%s\n' "$obj"
}

soviez_backup_inventory_pin() {
  local backup_id="$1"
  local obj prod_id
  obj="$(soviez_backup_read_object "$backup_id")"
  prod_id="$(soviez_json_get "$obj" production_id)"
  obj="$(soviez_backup_patch_object "$prod_id" "$backup_id" '{"pinned":true}')"
  soviez_backup_inventory_upsert "$obj"
  soviez_backup_ok BACKUP_PINNED "Pinned $backup_id"
}

soviez_backup_inventory_unpin() {
  local backup_id="$1"
  local obj prod_id
  obj="$(soviez_backup_read_object "$backup_id")"
  prod_id="$(soviez_json_get "$obj" production_id)"
  obj="$(soviez_backup_patch_object "$prod_id" "$backup_id" '{"pinned":false}')"
  soviez_backup_inventory_upsert "$obj"
  soviez_backup_ok BACKUP_UNPINNED "Unpinned $backup_id"
}

soviez_backup_inventory_remove() {
  local backup_id="$1"
  local idx new_idx
  idx="$(soviez_backup_inventory_load)"
  new_idx="$(SOVIEZ_IDX="$idx" SOVIEZ_BID="$backup_id" python3 - <<'PY'
import json, os
idx = json.loads(os.environ["SOVIEZ_IDX"])
bid = os.environ["SOVIEZ_BID"]
idx["backups"] = [b for b in idx.get("backups", []) if b.get("backup_id") != bid]
print(json.dumps(idx, separators=(",", ":")))
PY
)"
  soviez_backup_inventory_atomic_write "$new_idx"
}
