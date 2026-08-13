# shellcheck shell=bash
# Local resource admission — commercial Stage count unlimited; server capacity limited.

soviez_stage_admission_evaluate() {
  # Args: source_db_bytes source_filestore_bytes
  local db_bytes="${1:-0}"
  local fs_bytes="${2:-0}"
  local avail_kb inode_free mem_kb load_1 stage_count
  avail_kb="$(df -Pk "${SOVIEZ_STAGES_DIR:-/var/soviez}" 2>/dev/null | awk 'NR==2{print $4}')"
  avail_kb="${avail_kb:-0}"
  inode_free="$(df -Pi "${SOVIEZ_STAGES_DIR:-/var/soviez}" 2>/dev/null | awk 'NR==2{print $4}')"
  inode_free="${inode_free:-999999}"
  mem_kb="$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}' || echo 8388608)"
  load_1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || echo 0)"
  stage_count="$(soviez_stage_inventory_list_ids 2>/dev/null | grep -c . || true)"
  stage_count="${stage_count:-0}"

  # Projected need: dump + restore + filestore clone + 20% buffer + 2GiB workspace.
  local projected=$(( (db_bytes + fs_bytes) * 25 / 10 + 2147483648 ))
  local avail_bytes=$((avail_kb * 1024))
  local status="ready"
  local denial=""

  if [[ "$avail_bytes" -lt "$projected" ]]; then
    status="blocked"
    denial="INSUFFICIENT_DISK"
  elif [[ "$inode_free" -lt 10000 ]]; then
    status="blocked"
    denial="INSUFFICIENT_DISK"
  elif [[ "$mem_kb" -lt 1048576 ]]; then
    status="blocked"
    denial="INSUFFICIENT_MEMORY"
  elif python3 -c "import sys; sys.exit(0 if float('${load_1:-0}')>16 else 1)" 2>/dev/null; then
    status="warning"
  elif [[ "$stage_count" -ge 50 ]]; then
    status="warning"
  fi

  SOVIEZ_ST="$status" SOVIEZ_DEN="$denial" SOVIEZ_PROJ="$projected" SOVIEZ_AVAIL="$avail_bytes" \
    SOVIEZ_MEM="$mem_kb" SOVIEZ_LOAD="$load_1" SOVIEZ_CNT="$stage_count" python3 - <<'PY'
import json, os
print(json.dumps({
  "status": os.environ["SOVIEZ_ST"],
  "denial_code": os.environ.get("SOVIEZ_DEN") or None,
  "projected_bytes": int(os.environ["SOVIEZ_PROJ"]),
  "available_bytes": int(os.environ["SOVIEZ_AVAIL"]),
  "mem_available_kb": int(float(os.environ["SOVIEZ_MEM"])),
  "load_1": os.environ["SOVIEZ_LOAD"],
  "current_stage_count": int(os.environ["SOVIEZ_CNT"]),
  "commercial_limit": "unlimited",
  "formula": "projected=(db+fs)*2.5 + 2GiB; blocked if avail < projected or MemAvailable < 1GiB",
}, separators=(",", ":")))
PY
}

soviez_stage_admission_require() {
  local result="$1"
  local status
  status="$(soviez_json_get "$result" status)"
  if [[ "$status" == "blocked" ]]; then
    local code
    code="$(soviez_json_get "$result" denial_code)"
    soviez_stage_die "${code:-RESOURCE_ADMISSION_FAILED}" "Local resource admission blocked"
  fi
  if [[ "$status" == "warning" && "${SOVIEZ_STAGE_ADMISSION_FORCE:-0}" != "1" ]]; then
    if [[ ! -t 0 ]]; then
      soviez_stage_die RESOURCE_ADMISSION_FAILED "Admission warning requires confirmation (set SOVIEZ_STAGE_ADMISSION_FORCE=1 for non-TTY)"
    fi
    printf 'Resource admission WARNING. Continue? [y/N] ' >&2
    local ans
    read -r ans || true
    [[ "$ans" =~ ^[Yy]$ ]] || soviez_stage_die RESOURCE_ADMISSION_FAILED "Aborted on admission warning"
  fi
}
