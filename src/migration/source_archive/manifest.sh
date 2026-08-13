# shellcheck shell=bash

soviez_migration_p22_archive_write_manifest() {
  local op_id="$1" cutover_id="$2" source_id="$3"
  local op_dir manifest pinned
  op_dir="$(soviez_migration_p22_archive_op_dir "$op_id")"
  manifest="$op_dir/manifest.json"
  pinned="${SOVIEZ_MIG_P22_PINNED_BACKUP:-}"
  [[ -n "$pinned" && -e "$pinned" ]] || \
    soviez_migration_die MIGRATION_SOURCE_BACKUP_REQUIRED "independent recovery copy (pinned rollback backup) required"

  local enc_sha
  enc_sha="$(soviez_json_get "$(cat "$op_dir/encryption.json")" sha256)"

  SOVIEZ_OUT="$manifest" SOVIEZ_OP="$op_id" SOVIEZ_CID="$cutover_id" SOVIEZ_SID="$source_id" \
  SOVIEZ_ENC="$enc_sha" SOVIEZ_PIN="$pinned" SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
body={
  "schema":"soviez.migration_source_archive_manifest.v1",
  "operation_id": os.environ["SOVIEZ_OP"],
  "cutover_id": os.environ["SOVIEZ_CID"],
  "source_id": os.environ["SOVIEZ_SID"],
  "encrypted_sha256": os.environ["SOVIEZ_ENC"],
  "independent_recovery_copy": os.environ["SOVIEZ_PIN"],
  "purge_authorized": False,
  "deletion_performed": False,
  "source_data_deleted": False,
  "backup_deleted": False,
  "certificate_revoked": False,
  "created_at": os.environ["SOVIEZ_NOW"],
  "signer": "soviez-p22",
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY
  cat "$manifest"
}
