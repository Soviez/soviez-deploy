# shellcheck shell=bash
# Security Gate S2 — cron/systemd/loader persistence audit (read-only; groundwork for S3).

soviez_persist_cron_inventory() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="${SOVIEZ_PERSIST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-persist}/cron.txt"
  mkdir -p "$(dirname "$out")"
  {
    echo "## root crontab"
    crontab -l 2>/dev/null || echo "(none)"
    echo "## /etc/crontab"
    [[ -f /etc/crontab ]] && cat /etc/crontab || echo "(absent)"
    for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
      echo "## ${d}"
      if [[ -d "$d" ]]; then
        ls -la "$d" 2>/dev/null || true
      else
        echo "(absent)"
      fi
    done
  } >"$out"
  printf '%s\n' "$out"
}

soviez_persist_systemd_inventory() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="${SOVIEZ_PERSIST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-persist}/systemd.txt"
  mkdir -p "$(dirname "$out")"
  {
    echo "## services"
    systemctl list-unit-files --type=service 2>/dev/null | head -500 || echo "systemctl_absent"
    echo "## timers"
    systemctl list-timers --all 2>/dev/null | head -200 || echo "timers_absent"
  } >"$out"
  printf '%s\n' "$out"
}

soviez_persist_rc_profile_inventory() {
  local out="${1:-}"
  [[ -n "$out" ]] || out="${SOVIEZ_PERSIST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-persist}/rc_profile.txt"
  mkdir -p "$(dirname "$out")"
  {
    for f in /etc/rc.local /etc/profile /etc/bash.bashrc /etc/profile.d/*; do
      [[ -e "$f" ]] || continue
      echo "## ${f}"
      ls -la "$f" 2>/dev/null || true
    done
  } >"$out"
  printf '%s\n' "$out"
}

soviez_persist_ld_preload_audit() {
  local path="/etc/ld.so.preload"
  if [[ ! -f "$path" ]]; then
    printf '%s\n' "ABSENT"
    return 0
  fi
  if [[ ! -s "$path" ]]; then
    printf '%s\n' "EMPTY"
    return 0
  fi
  # Non-empty unexpected content → HIGH/CRITICAL report (do not auto-remove).
  printf '%s\n' "UNEXPECTED"
  return 0
}

soviez_persist_record_baseline() {
  local dir="${1:-${SOVIEZ_PERSIST_BASELINE_DIR:-${TMPDIR:-/tmp}/soviez-persist}}"
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  SOVIEZ_PERSIST_BASELINE_DIR="$dir"
  export SOVIEZ_PERSIST_BASELINE_DIR
  soviez_persist_cron_inventory "$dir/cron.txt" >/dev/null
  soviez_persist_systemd_inventory "$dir/systemd.txt" >/dev/null
  soviez_persist_rc_profile_inventory "$dir/rc_profile.txt" >/dev/null
  soviez_persist_ld_preload_audit >"$dir/ld_preload.txt"
  # Fingerprint
  if command -v openssl >/dev/null 2>&1; then
    cat "$dir"/*.txt 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}' >"$dir/fingerprint.sha256"
  fi
  date -u +%Y-%m-%dT%H:%M:%SZ >"$dir/recorded_utc"
  printf '%s\n' "$dir"
}
