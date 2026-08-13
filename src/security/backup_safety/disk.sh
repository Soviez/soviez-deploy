# shellcheck shell=bash
# Security Gate S5 — disk space preflight before heavy backup/update ops.

soviez_s5_disk_preflight() {
  local need_kb="${1:-0}"
  local path="${2:-${SOVIEZ_S5_DISK_PATH:-${TMPDIR:-/tmp}}}"
  local margin_kb="${SOVIEZ_S5_DISK_MARGIN_KB:-1048576}" # default 1 GiB margin

  if [[ "${SOVIEZ_S5_INJECT_DISK_FAIL:-0}" == "1" ]]; then
    echo FAIL
    return 1
  fi

  if ! [[ "$need_kb" =~ ^[0-9]+$ ]]; then
    echo FAIL
    return 1
  fi

  local avail
  avail="$(df -Pk "$path" 2>/dev/null | awk 'NR==2{print $4}')"
  if [[ -z "$avail" || ! "$avail" =~ ^[0-9]+$ ]]; then
    if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
      avail="${SOVIEZ_S5_DISK_AVAIL_KB:-999999999}"
    else
      echo FAIL
      return 1
    fi
  fi

  local required=$((need_kb + margin_kb))
  if [[ "$avail" -lt "$required" ]]; then
    echo "[error] security:SEC_HIGH_DISK_INSUFFICIENT: need_kb=${required} avail_kb=${avail} path=${path}" >&2
    echo FAIL
    return 1
  fi
  echo PASS
  return 0
}
