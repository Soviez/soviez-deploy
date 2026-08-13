# shellcheck shell=bash

# Staging margin: 1.5x documented component sum (db dump staging + filestore archive
# staging + encryption framing + verification workspace). Not a magic constant —
# each contributor is enumerated below.

SOVIEZ_BACKUP_STAGING_MARGIN_NUM="${SOVIEZ_BACKUP_STAGING_MARGIN_NUM:-3}"
SOVIEZ_BACKUP_STAGING_MARGIN_DEN="${SOVIEZ_BACKUP_STAGING_MARGIN_DEN:-2}"

soviez_backup_bytes_of_path() {
  local path="$1"
  if [[ -z "$path" || ! -e "$path" ]]; then
    printf '0\n'
    return 0
  fi
  du -sk "$path" 2>/dev/null | awk '{print $1*1024}' || echo 0
}

soviez_backup_capacity_calc() {
  # Args: production_json [destination_root]
  local prod_json="$1" dest_root="${2:-${SOVIEZ_BACKUP_ROOT:-}}"
  local db_bytes=0 fs_bytes=0 meta_bytes=65536
  local db_path fs_path
  db_path="$(soviez_json_get "$prod_json" database_path 2>/dev/null || true)"
  fs_path="$(soviez_json_get "$prod_json" filestore_path 2>/dev/null || true)"

  if [[ -n "$db_path" && -e "$db_path" ]]; then
    db_bytes="$(soviez_backup_bytes_of_path "$db_path")"
  else
    db_bytes="$(soviez_json_get "$prod_json" database_bytes 2>/dev/null || echo 1048576)"
  fi
  if [[ -n "$fs_path" && -e "$fs_path" ]]; then
    fs_bytes="$(soviez_backup_bytes_of_path "$fs_path")"
  else
    fs_bytes="$(soviez_json_get "$prod_json" filestore_bytes 2>/dev/null || echo 1048576)"
  fi

  # Documented contributors (conservative / near-uncompressed for dump + archive)
  local dump_staging="$db_bytes"
  local filestore_staging="$fs_bytes"
  local encryption_overhead=$(( 1024 * 1024 ))   # framing + IV/HMAC envelope
  local verify_workspace=$(( db_bytes / 20 + fs_bytes / 50 + 16 * 1024 * 1024 ))
  local remote_multipart=0
  local components_sum=$(( dump_staging + filestore_staging + meta_bytes + encryption_overhead + verify_workspace + remote_multipart ))

  # Staging margin 1.5x = 3/2 on documented components
  local required=$(( components_sum * SOVIEZ_BACKUP_STAGING_MARGIN_NUM / SOVIEZ_BACKUP_STAGING_MARGIN_DEN ))
  local margin=$(( required - components_sum ))

  local avail=0
  if [[ -n "$dest_root" && -d "$dest_root" ]]; then
    avail="$(df -k "$dest_root" 2>/dev/null | awk 'NR==2{print $4*1024}' || echo 0)"
  elif [[ -n "${SOVIEZ_BACKUP_ROOT:-}" ]]; then
    avail="$(df -k "$SOVIEZ_BACKUP_ROOT" 2>/dev/null | awk 'NR==2{print $4*1024}' || echo 0)"
  fi
  if [[ "${SOVIEZ_BACKUP_FIXTURE_AVAILABLE_BYTES:-}" =~ ^[0-9]+$ ]]; then
    avail="$SOVIEZ_BACKUP_FIXTURE_AVAILABLE_BYTES"
  fi

  local inodes_avail
  inodes_avail="$(df -i "${dest_root:-${SOVIEZ_BACKUP_ROOT:-/}}" 2>/dev/null | awk 'NR==2{print $4}' || echo 999999)"
  if [[ "${SOVIEZ_BACKUP_FIXTURE_AVAILABLE_INODES:-}" =~ ^[0-9]+$ ]]; then
    inodes_avail="$SOVIEZ_BACKUP_FIXTURE_AVAILABLE_INODES"
  fi

  SOVIEZ_REQ="$required" SOVIEZ_AVAIL="$avail" SOVIEZ_MARGIN="$margin" \
  SOVIEZ_DB="$db_bytes" SOVIEZ_FS="$fs_bytes" SOVIEZ_META="$meta_bytes" \
  SOVIEZ_ENC="$encryption_overhead" SOVIEZ_VER="$verify_workspace" \
  SOVIEZ_IN="$inodes_avail" SOVIEZ_NUM="$SOVIEZ_BACKUP_STAGING_MARGIN_NUM" \
  SOVIEZ_DEN="$SOVIEZ_BACKUP_STAGING_MARGIN_DEN" python3 - <<'PY'
import json, os
print(json.dumps({
  "required_bytes": int(os.environ["SOVIEZ_REQ"]),
  "available_bytes": int(os.environ["SOVIEZ_AVAIL"]),
  "safety_margin_bytes": int(os.environ["SOVIEZ_MARGIN"]),
  "staging_margin_factor": f'{os.environ["SOVIEZ_NUM"]}/{os.environ["SOVIEZ_DEN"]}',
  "available_inodes": int(os.environ["SOVIEZ_IN"]),
  "contributors": [
    {"name": "database_dump_staging", "bytes": int(os.environ["SOVIEZ_DB"])},
    {"name": "filestore_archive_staging", "bytes": int(os.environ["SOVIEZ_FS"])},
    {"name": "metadata_manifest", "bytes": int(os.environ["SOVIEZ_META"])},
    {"name": "encryption_overhead", "bytes": int(os.environ["SOVIEZ_ENC"])},
    {"name": "verification_workspace", "bytes": int(os.environ["SOVIEZ_VER"])},
  ],
  "largest_contributors": sorted([
    {"name": "database_dump_staging", "bytes": int(os.environ["SOVIEZ_DB"])},
    {"name": "filestore_archive_staging", "bytes": int(os.environ["SOVIEZ_FS"])},
    {"name": "verification_workspace", "bytes": int(os.environ["SOVIEZ_VER"])},
  ], key=lambda x: -x["bytes"])[:3],
  "remediation": [
    "Free disk under backup root",
    "Reduce filestore before backup",
    "Move destination to larger volume",
  ],
}, separators=(",", ":")))
PY
}

soviez_backup_capacity_assert() {
  local cap="$1"
  local req avail inodes
  req="$(soviez_json_get "$cap" required_bytes)"
  avail="$(soviez_json_get "$cap" available_bytes)"
  inodes="$(soviez_json_get "$cap" available_inodes)"
  [[ "$avail" -ge "$req" ]] || soviez_backup_die BACKUP_DISK_INSUFFICIENT "Need $req bytes, have $avail"
  [[ "$inodes" -ge 1000 ]] || soviez_backup_die BACKUP_INODES_INSUFFICIENT "Insufficient inodes: $inodes"
}
