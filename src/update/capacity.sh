# shellcheck shell=bash

soviez_update_capacity_calc() {
  local prod_json="$1" target_digest_size="${2:-0}"
  local db_bytes=0 fs_bytes=0 img_bytes=0
  local db_path fs_path
  db_path="$(soviez_json_get "$prod_json" database_path 2>/dev/null || true)"
  fs_path="$(soviez_json_get "$prod_json" filestore_path 2>/dev/null || true)"
  if [[ -n "$db_path" && -e "$db_path" ]]; then
    db_bytes="$(du -sk "$db_path" 2>/dev/null | awk '{print $1*1024}' || echo 0)"
  else
    db_bytes="$(soviez_json_get "$prod_json" database_bytes 2>/dev/null || echo 1048576)"
  fi
  if [[ -n "$fs_path" && -e "$fs_path" ]]; then
    fs_bytes="$(du -sk "$fs_path" 2>/dev/null | awk '{print $1*1024}' || echo 0)"
  else
    fs_bytes="$(soviez_json_get "$prod_json" filestore_bytes 2>/dev/null || echo 1048576)"
  fi
  img_bytes="$(soviez_json_get "$prod_json" image_bytes 2>/dev/null || echo 268435456)"
  [[ "$target_digest_size" -gt 0 ]] || target_digest_size="$img_bytes"

  # Measured contributors + documented safety margin (25% on sum of clones)
  local backup_db="$db_bytes" backup_fs="$fs_bytes"
  local candidate_db="$db_bytes" candidate_fs="$fs_bytes"
  local candidate_img="$target_digest_size"
  local overhead=$(( db_bytes / 10 + 64*1024*1024 )) # ~10% temp + 64MiB logs/evidence
  local rollback_reserve="$backup_db" # keep prior DB copy
  local required=$(( backup_db + backup_fs + candidate_db + candidate_fs + candidate_img + overhead + rollback_reserve/2 ))
  local margin=$(( required / 4 ))
  required=$(( required + margin ))

  local avail
  avail="$(df -k "$SOVIEZ_UPDATE_ROOT" 2>/dev/null | awk 'NR==2{print $4*1024}' || echo 0)"
  if [[ "${SOVIEZ_UPDATE_FIXTURE_AVAILABLE_BYTES:-}" =~ ^[0-9]+$ ]]; then
    avail="$SOVIEZ_UPDATE_FIXTURE_AVAILABLE_BYTES"
  fi
  local inodes_avail
  inodes_avail="$(df -i "$SOVIEZ_UPDATE_ROOT" 2>/dev/null | awk 'NR==2{print $4}' || echo 999999)"
  if [[ "${SOVIEZ_UPDATE_FIXTURE_AVAILABLE_INODES:-}" =~ ^[0-9]+$ ]]; then
    inodes_avail="$SOVIEZ_UPDATE_FIXTURE_AVAILABLE_INODES"
  fi
  local mem_avail="${SOVIEZ_UPDATE_FIXTURE_AVAILABLE_MEMORY_BYTES:-}"
  if [[ ! "$mem_avail" =~ ^[0-9]+$ ]]; then
    mem_avail="$(sysctl -n hw.memsize 2>/dev/null || awk '/MemAvailable/{print $2*1024}' /proc/meminfo 2>/dev/null || echo 8589934592)"
  fi

  SOVIEZ_REQ="$required" SOVIEZ_AVAIL="$avail" SOVIEZ_MARGIN="$margin" \
  SOVIEZ_DB="$db_bytes" SOVIEZ_FS="$fs_bytes" SOVIEZ_IMG="$candidate_img" \
  SOVIEZ_IN="$inodes_avail" SOVIEZ_MEM="$mem_avail" python3 - <<'PY'
import json,os
print(json.dumps({
  "required_bytes": int(os.environ["SOVIEZ_REQ"]),
  "available_bytes": int(os.environ["SOVIEZ_AVAIL"]),
  "safety_margin_bytes": int(os.environ["SOVIEZ_MARGIN"]),
  "available_inodes": int(os.environ["SOVIEZ_IN"]),
  "available_memory_bytes": int(os.environ["SOVIEZ_MEM"]),
  "largest_contributors": [
    {"name":"candidate_filestore_copy","bytes":int(os.environ["SOVIEZ_FS"])},
    {"name":"backup_database","bytes":int(os.environ["SOVIEZ_DB"])},
    {"name":"candidate_image","bytes":int(os.environ["SOVIEZ_IMG"])},
  ],
  "remediation":["Free disk on update root","Reduce filestore before update","Move backups to larger volume"],
},separators=(",",":")))
PY
}

soviez_update_capacity_assert() {
  local cap="$1"
  local req avail inodes mem
  req="$(soviez_json_get "$cap" required_bytes)"
  avail="$(soviez_json_get "$cap" available_bytes)"
  inodes="$(soviez_json_get "$cap" available_inodes)"
  mem="$(soviez_json_get "$cap" available_memory_bytes)"
  [[ "$avail" -ge "$req" ]] || soviez_update_die UPDATE_DISK_INSUFFICIENT "Need $req bytes, have $avail"
  [[ "$inodes" -ge 10000 ]] || soviez_update_die UPDATE_INODES_INSUFFICIENT "Insufficient inodes: $inodes"
  [[ "$mem" -ge 536870912 ]] || soviez_update_die UPDATE_MEMORY_INSUFFICIENT "Insufficient memory: $mem"
}
