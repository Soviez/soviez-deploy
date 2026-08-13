# shellcheck shell=bash
# Security Gate S3 — lightweight host integrity (native fingerprints; AIDE deferred).

soviez_s3_host_integrity_scan() {
  local out_dir="${1:-}"
  [[ -n "$out_dir" ]] || out_dir="$(mktemp -d)"
  mkdir -p "$out_dir"
  local status="PASS"
  local findings=()
  # Disposable fixture root for tests (never mutate live /etc on developer hosts).
  local fx="${SOVIEZ_S3_HOST_FIXTURE_ROOT:-}"

  # ld.so.preload
  local preload="${fx}/etc/ld.so.preload"
  [[ -n "$fx" ]] || preload="/etc/ld.so.preload"
  if [[ ! -f "$preload" ]]; then
    echo "ld_preload=ABSENT" >"$out_dir/ld_preload.txt"
  elif [[ ! -s "$preload" ]]; then
    echo "ld_preload=EMPTY" >"$out_dir/ld_preload.txt"
  else
    echo "ld_preload=UNEXPECTED" >"$out_dir/ld_preload.txt"
    status="FAIL"
    findings+=("SEC_CRIT_HOST_LD_PRELOAD_SUSPICIOUS")
  fi

  # Soviez-owned / local paths fingerprint (bounded)
  local paths=(
    /usr/local/bin
    /usr/local/sbin
  )
  [[ -n "${SOVIEZ_ROOT:-}" && -d "${SOVIEZ_ROOT}" ]] && paths+=("${SOVIEZ_ROOT}")
  : >"$out_dir/path_hashes.txt"
  local p
  for p in "${paths[@]}"; do
    [[ -d "$p" ]] || continue
    find "$p" -xdev -type f 2>/dev/null | head -200 | while read -r f; do
      openssl dgst -sha256 "$f" 2>/dev/null | awk -v f="$f" '{print $NF"  "f}'
    done >>"$out_dir/path_hashes.txt" || true
  done

  # UID0 (fixture passwd when provided)
  local passwd_f="/etc/passwd"
  [[ -n "$fx" && -f "${fx}/etc/passwd" ]] && passwd_f="${fx}/etc/passwd"
  if [[ -f "$passwd_f" ]]; then
    awk -F: '$3==0{print $1}' "$passwd_f" >"$out_dir/uid0.txt"
    local n
    n="$(wc -l <"$out_dir/uid0.txt" | tr -d ' ')"
    if [[ "${n:-0}" -gt 1 ]]; then
      findings+=("SEC_CRIT_HOST_UNEXPECTED_UID0")
      status="FAIL"
    fi
  fi

  # Optional SUID/SGID/capability drift vs fixture baseline list
  if [[ -n "${SOVIEZ_S3_SUID_BASELINE:-}" && -f "${SOVIEZ_S3_SUID_BASELINE}" ]]; then
    local cur_suid
    cur_suid="$(mktemp)"
    if [[ -n "$fx" ]]; then
      find "$fx" -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | sort >"$cur_suid" || true
    else
      # Bounded sample only — do not walk entire host
      find /usr/local /opt/soviez "${SOVIEZ_ROOT:-/nonexistent}" -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | sort >"$cur_suid" || true
    fi
    if ! cmp -s "${SOVIEZ_S3_SUID_BASELINE}" "$cur_suid"; then
      findings+=("SEC_HIGH_UNKNOWN_SUID_DRIFT")
      [[ "$status" == "PASS" ]] && status="PASS_WITH_REVIEW"
      # If new paths beyond package baseline → HIGH (still FAIL only if CRITICAL elsewhere)
      if [[ "${SOVIEZ_S3_SUID_STRICT:-0}" == "1" ]]; then
        status="FAIL"
      fi
      cp -f "$cur_suid" "$out_dir/suid_current.txt"
    fi
    rm -f "$cur_suid"
  fi

  printf '%s\n' "$status" >"$out_dir/STATUS"
  printf '%s\n' "${findings[@]-}" >"$out_dir/codes.txt"
  printf '%s\n' "$out_dir"
  [[ "$status" != "FAIL" ]]
}

soviez_s3_aide_decision() {
  # AIDE deferred: Docker overlay + Odoo filestore + PG data churn make naive FIM costly.
  # Native bounded fingerprints cover Soviez-owned paths for S3.
  printf '%s\n' "DEFERRED_NATIVE_FINGERPRINTS"
}
