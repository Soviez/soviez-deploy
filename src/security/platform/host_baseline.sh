# shellcheck shell=bash
# Security Gate S2 — host administrative surface baseline (read-only).

soviez_host_uid0_audit() {
  # List UID 0 accounts (read-only).
  if [[ ! -f /etc/passwd ]]; then
    echo "passwd_absent"
    return 0
  fi
  awk -F: '$3==0 {print $1}' /etc/passwd
}

soviez_host_login_shell_audit() {
  # Unexpected shells for system users — report only.
  if [[ ! -f /etc/passwd ]]; then
    return 0
  fi
  awk -F: '$3<1000 && $7 !~ /(\/nologin|\/false|\/sync)/ {print $1":"$7}' /etc/passwd 2>/dev/null || true
}

soviez_host_suid_baseline() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="${SOVIEZ_HOST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-host-bl}/suid.txt"
  mkdir -p "$(dirname "$out")"
  # Bounded find — do not follow into huge trees forever in tests.
  local roots=(/usr/bin /usr/sbin /bin /sbin)
  : >"$out"
  local r
  for r in "${roots[@]}"; do
    [[ -d "$r" ]] || continue
    find "$r" -xdev -perm -4000 -type f 2>/dev/null | sort >>"$out" || true
  done
  printf '%s\n' "$out"
}

soviez_host_sgid_baseline() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="${SOVIEZ_HOST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-host-bl}/sgid.txt"
  mkdir -p "$(dirname "$out")"
  local roots=(/usr/bin /usr/sbin /bin /sbin)
  : >"$out"
  local r
  for r in "${roots[@]}"; do
    [[ -d "$r" ]] || continue
    find "$r" -xdev -perm -2000 -type f 2>/dev/null | sort >>"$out" || true
  done
  printf '%s\n' "$out"
}

soviez_host_capabilities_baseline() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="${SOVIEZ_HOST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-host-bl}/caps.txt"
  mkdir -p "$(dirname "$out")"
  : >"$out"
  if command -v getcap >/dev/null 2>&1; then
    getcap -r /usr/bin /usr/sbin 2>/dev/null | sort >"$out" || true
  else
    echo "getcap_absent" >"$out"
  fi
  printf '%s\n' "$out"
}

soviez_host_record_baseline() {
  local dir="${1:-${SOVIEZ_HOST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-host-bl}}"
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  SOVIEZ_HOST_BASELINE_DIR="$dir"
  export SOVIEZ_HOST_BASELINE_DIR
  soviez_host_uid0_audit >"$dir/uid0.txt"
  soviez_host_login_shell_audit >"$dir/login_shells.txt"
  soviez_host_suid_baseline "$dir/suid.txt" >/dev/null
  soviez_host_sgid_baseline "$dir/sgid.txt" >/dev/null
  soviez_host_capabilities_baseline "$dir/caps.txt" >/dev/null
  date -u +%Y-%m-%dT%H:%M:%SZ >"$dir/recorded_utc"
  printf '%s\n' "$dir"
}
