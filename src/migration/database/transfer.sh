# shellcheck shell=bash

soviez_migration_database_transfer() {
  local pair_id="$1" op_id="$2" manifest_id="$3"
  local dump_file object_id meta
  dump_file="$(soviez_migration_transfer_op_dir "$op_id")/database/dump.fc"
  [[ -f "$dump_file" ]] || soviez_migration_die MIGRATION_DATABASE_TRANSFER_FAILED "Dump missing"
  meta="$(cat "$(soviez_migration_transfer_op_dir "$op_id")/database/dump_meta.json")"
  object_id="db-$(soviez_json_get "$meta" sha256 | cut -c1-16)"
  # Optional compress (skip in fixture mode for sandbox portability)
  local transfer_file="$dump_file" algo="none"
  if [[ "${SOVIEZ_MIG_FORCE_FIXTURE_DB:-0}" != "1" && "${SOVIEZ_TEST_MODE:-0}" != "1" ]]; then
    if command -v zstd >/dev/null 2>&1 || command -v gzip >/dev/null 2>&1; then
      transfer_file="$(soviez_migration_transfer_op_dir "$op_id")/database/dump.fc.compressed"
      algo="$(soviez_migration_compress_file "$dump_file" "$transfer_file")"
    fi
  fi
  [[ -f "$transfer_file" ]] || transfer_file="$dump_file"
  soviez_migration_chunk_plan_file "$op_id" "$object_id" "database" "$transfer_file" >/dev/null
  soviez_migration_chunk_transfer_all "$op_id" "${SOVIEZ_MIG_RESOURCE_PROFILE:-balanced}" >/dev/null
  local assembled
  assembled="$(soviez_migration_transfer_chunks_dir "$op_id")/assembled/${object_id}.bin"
  soviez_migration_chunk_assemble_object "$op_id" "$object_id" "$assembled" >/dev/null
  # Decompress if needed into staging-ready path
  local final="$dump_file"
  if [[ "$algo" != "none" ]]; then
    final="$(soviez_migration_transfer_op_dir "$op_id")/database/dump.fc.verified"
    soviez_migration_decompress_file "$assembled" "$final" "$algo"
  else
    cp -f "$assembled" "$final"
  fi
  soviez_migration_transfer_manifest_add_object "$manifest_id" "$(SOVIEZ_OID="$object_id" SOVIEZ_M="$meta" SOVIEZ_P="$final" python3 - <<'PY'
import json, os
m=json.loads(os.environ["SOVIEZ_M"])
print(json.dumps({
  "object_id": os.environ["SOVIEZ_OID"],
  "category": "database",
  "sha256": m.get("sha256"),
  "size_bytes": m.get("size_bytes"),
  "local_path": os.environ["SOVIEZ_P"],
}, separators=(",", ":")))
PY
)" >/dev/null
  printf '{"object_id":"%s","status":"transferred","path":"%s"}\n' "$object_id" "$final"
}
