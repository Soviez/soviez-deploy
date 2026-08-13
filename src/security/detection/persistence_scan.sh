# shellcheck shell=bash
# Security Gate S3 — persistence drift vs baseline inventory (read-only; fixture-aware).

soviez_s3_persistence_scan() {
  local baseline_dir="${1:-}"
  local out="${2:-}"
  [[ -n "$out" ]] || out="$(mktemp -d)"
  mkdir -p "$out/current"
  local fx="${SOVIEZ_S3_HOST_FIXTURE_ROOT:-}"
  local status="PASS"

  # ld.so.preload
  local preload="/etc/ld.so.preload"
  [[ -n "$fx" ]] && preload="${fx}/etc/ld.so.preload"
  if [[ ! -f "$preload" ]]; then
    echo ABSENT >"$out/current/ld_preload.txt"
  elif [[ ! -s "$preload" ]]; then
    echo EMPTY >"$out/current/ld_preload.txt"
  else
    echo UNEXPECTED >"$out/current/ld_preload.txt"
    status="FAIL"
    echo "SEC_CRIT_HOST_LD_PRELOAD_SUSPICIOUS" >>"$out/codes.txt"
  fi

  # Cron inventory (fixture or live read-only)
  if [[ -n "$fx" ]]; then
    find "${fx}/etc/cron.d" "${fx}/var/spool/cron" "${fx}/etc/crontab" -type f 2>/dev/null | sort >"$out/current/cron_paths.txt" || true
    [[ -f "${fx}/etc/crontab" ]] && cat "${fx}/etc/crontab" >"$out/current/crontab.txt" || echo none >"$out/current/crontab.txt"
  else
    crontab -l >"$out/current/crontab.txt" 2>/dev/null || echo none >"$out/current/crontab.txt"
    find /etc/cron.d /etc/cron.daily /var/spool/cron 2>/dev/null | sort >"$out/current/cron_paths.txt" || true
  fi

  # systemd unit inventory (fixture or bounded live)
  if [[ -n "$fx" ]]; then
    find "${fx}/etc/systemd/system" "${fx}/lib/systemd/system" -type f -name '*.service' 2>/dev/null | sort >"$out/current/systemd_units.txt" || true
  else
    find /etc/systemd/system /lib/systemd/system -maxdepth 2 -type f -name 'soviez*.service' 2>/dev/null | sort >"$out/current/systemd_units.txt" || true
  fi

  # rc.local / profile
  : >"$out/current/startup.txt"
  for f in /etc/rc.local /etc/profile /etc/profile.d/soviez.sh; do
    local rf="$f"
    [[ -n "$fx" ]] && rf="${fx}${f}"
    [[ -f "$rf" ]] && echo "PRESENT $f" >>"$out/current/startup.txt"
  done

  # Drift vs baseline lists
  if [[ -n "$baseline_dir" ]]; then
    if [[ -f "$baseline_dir/cron_paths.txt" && -f "$out/current/cron_paths.txt" ]]; then
      if ! cmp -s "$baseline_dir/cron_paths.txt" "$out/current/cron_paths.txt"; then
        echo "SEC_HIGH_CRON_PERSISTENCE_DRIFT" >>"$out/codes.txt"
        [[ "$status" == "PASS" ]] && status="PASS_WITH_REVIEW"
        # New unexpected cron with shell downloaders → elevate
        if grep -Eiq 'curl|wget|xmrig|/dev/tcp' "$out/current/crontab.txt" 2>/dev/null; then
          status="FAIL"
        fi
      fi
    fi
    if [[ -f "$baseline_dir/systemd_units.txt" && -f "$out/current/systemd_units.txt" ]]; then
      if ! cmp -s "$baseline_dir/systemd_units.txt" "$out/current/systemd_units.txt"; then
        echo "SEC_HIGH_SYSTEMD_PERSISTENCE_DRIFT" >>"$out/codes.txt"
        [[ "$status" == "PASS" ]] && status="PASS_WITH_REVIEW"
      fi
    fi
  fi

  printf '%s\n' "$status" >"$out/STATUS"
  printf '%s\n' "$out"
  [[ "$status" != "FAIL" ]]
}
