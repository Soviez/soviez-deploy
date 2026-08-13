# shellcheck shell=bash

soviez_migration_filestore_presync() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local inv man generation=1
  inv="$(soviez_migration_filestore_inventory "$pair_id")"
  man="$(soviez_migration_filestore_manifest_write "$op_id" "$inv" "$generation")"
  # Transfer each file as chunked object when root exists
  local root
  root="$(soviez_json_get "$inv" root)"
  if [[ -n "$root" && -d "$root" ]]; then
    SOVIEZ_I="$inv" python3 -c 'import json,os; [print(f["path"]+"\t"+f["sha256"]) for f in json.loads(os.environ["SOVIEZ_I"]).get("files") or []]' \
    | while IFS=$'\t' read -r rel digest; do
        [[ -n "$rel" ]] || continue
        local src="$root/$rel"
        local oid="fs-$(printf '%s' "$rel" | openssl dgst -sha256 | awk '{print $NF}' | cut -c1-16)"
        soviez_migration_chunk_plan_file "$op_id" "$oid" "filestore" "$src" >/dev/null
        soviez_migration_chunk_transfer_all "$op_id" >/dev/null
      done
  else
    # Fixture empty presync still records generation
    :
  fi
  mkdir -p "$(soviez_migration_transfer_op_dir "$op_id")/filestore"
  printf '{"status":"presync_complete","generation":%s,"manifest_id":"%s"}\n' "$generation" "$manifest_id" \
    > "$(soviez_migration_transfer_op_dir "$op_id")/filestore/presync.json"
  cat "$(soviez_migration_transfer_op_dir "$op_id")/filestore/presync.json"
}
