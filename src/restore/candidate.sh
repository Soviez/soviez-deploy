# shellcheck shell=bash

soviez_restore_candidate_create() {
  # Args: op_id production_json backup_object_json
  # Non-slot candidate mirroring Phase 15 LG patterns when available.
  local op_id="$1" prod="$2" backup="$3"
  local cdir tenant_id license_id db_uuid backup_id
  soviez_restore_paths_init
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  mkdir -p "$cdir/db" "$cdir/filestore" "$cdir/runtime" "$cdir/network"
  chmod 700 "$cdir"

  tenant_id="$(soviez_json_get "$prod" tenant_id)"
  license_id="$(soviez_json_get "$prod" license_id)"
  db_uuid="$(soviez_json_get "$prod" database_uuid)"
  backup_id="$(soviez_json_get "$backup" backup_id)"

  printf 'container=soviez-rst-cand-%s\nnetwork=soviez-rst-net-%s\nrole=restore_candidate\nlicense_slot=none\ntemporary=1\n' \
    "$op_id" "$op_id" > "$cdir/runtime/identity.txt"
  printf '%s' "$db_uuid" > "$cdir/runtime/database_uuid.txt"
  printf '%s' "$license_id" > "$cdir/runtime/license_id.txt"
  printf '%s' "$tenant_id" > "$cdir/runtime/production_tenant_id.txt"
  printf '%s' "$backup_id" > "$cdir/runtime/backup_id.txt"

  cat > "$cdir/runtime/neutralization.env" <<EOF
SOVIEZ_CANDIDATE=1
SOVIEZ_RESTORE_CANDIDATE=1
SOVIEZ_MAIL_DISABLED=1
SOVIEZ_CRON_DISABLED=1
SOVIEZ_WEBHOOKS_DISABLED=1
SOVIEZ_PAYMENT_DISABLED=1
SOVIEZ_OUTBOUND_RESTRICTED=1
SOVIEZ_BACKGROUND_JOBS=neutralized
EOF

  if declare -F soviez_update_lg_identity_write >/dev/null 2>&1; then
    # Reuse LG writer with restore op id when update paths exist
    if declare -F soviez_update_paths_init >/dev/null 2>&1; then
      soviez_update_paths_init 2>/dev/null || true
    fi
    # Write LG-style identity into restore candidate runtime
    SOVIEZ_T="$tenant_id" SOVIEZ_L="$license_id" SOVIEZ_U="$db_uuid" SOVIEZ_B="$backup_id" \
    SOVIEZ_OP="$op_id" python3 - <<'PY' > "$cdir/runtime/license_guard_identity.json"
import json, os
from datetime import datetime, timezone, timedelta
exp = (datetime.now(timezone.utc) + timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "production_tenant_id": os.environ["SOVIEZ_T"],
  "license_id": os.environ["SOVIEZ_L"],
  "database_uuid": os.environ["SOVIEZ_U"],
  "backup_id": os.environ["SOVIEZ_B"],
  "independent_production": False,
  "non_sellable": True,
  "license_slot_consumed": False,
  "candidate_container_identity": True,
  "temporary": True,
  "expires_at": exp,
  "role": "restore_candidate",
}, separators=(",", ":")))
PY
  fi

  SOVIEZ_OP="$op_id" SOVIEZ_T="$tenant_id" SOVIEZ_B="$backup_id" python3 - <<'PY' > "$cdir/candidate.json"
import json, os
print(json.dumps({
  "operation_id": os.environ["SOVIEZ_OP"],
  "production_tenant_id": os.environ["SOVIEZ_T"],
  "backup_id": os.environ["SOVIEZ_B"],
  "license_slot_consumed": False,
  "temporary": True,
  "role": "restore_candidate",
  "neutralized": True,
}, separators=(",", ":")))
PY
  cat "$cdir/candidate.json"
}

soviez_restore_candidate_cleanup() {
  local op_id="$1"
  local cdir
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  rm -rf "$cdir"
}
