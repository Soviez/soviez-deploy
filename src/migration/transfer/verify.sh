# shellcheck shell=bash

soviez_migration_transfer_verify_manifest_objects() {
  local op_id="$1" manifest_id="$2"
  local man path oid digest expected
  man="$(soviez_migration_transfer_manifest_verify "$manifest_id")"
  SOVIEZ_M="$man" python3 -c '
import json,os
m=json.loads(os.environ["SOVIEZ_M"])
for o in m.get("objects") or []:
  print((o.get("object_id") or ""), (o.get("sha256") or ""), (o.get("local_path") or ""), sep="\t")
' | while IFS=$'\t' read -r oid expected path; do
    [[ -n "$oid" ]] || continue
    if [[ -n "$path" && -f "$path" ]]; then
      digest="$(openssl dgst -sha256 "$path" | awk '{print $NF}')"
      [[ -z "$expected" || "$digest" == "$expected" ]] || \
        soviez_migration_die MIGRATION_TRANSFER_CHUNK_CHECKSUM_MISMATCH "Object digest mismatch: $oid"
    fi
  done
  printf '{"operation_id":"%s","manifest_id":"%s","status":"verified"}\n' "$op_id" "$manifest_id"
}
