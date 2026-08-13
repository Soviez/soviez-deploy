# shellcheck shell=bash
# Security Gate S2 — SSH staged hardening (never brick management access).
# NEVER mutate the developer's workstation sshd from tests — use disposable guests.

SOVIEZ_SSH_POLICY="${SOVIEZ_SSH_POLICY:-staged}"

soviez_ssh_detect_state() {
  local conf="${1:-/etc/ssh/sshd_config}"
  local password_auth="unknown" root_login="unknown" port="22"
  if [[ -f "$conf" ]]; then
    password_auth="$(awk 'BEGIN{v="yes"} /^[[:space:]]*PasswordAuthentication[[:space:]]/{v=$2} END{print tolower(v)}' "$conf" 2>/dev/null || echo unknown)"
    root_login="$(awk 'BEGIN{v="yes"} /^[[:space:]]*PermitRootLogin[[:space:]]/{v=$2} END{print tolower(v)}' "$conf" 2>/dev/null || echo unknown)"
    port="$(awk 'BEGIN{v="22"} /^[[:space:]]*Port[[:space:]]/{v=$2} END{print v}' "$conf" 2>/dev/null || echo 22)"
  fi
  printf 'password_auth=%s root_login=%s port=%s\n' "$password_auth" "$root_login" "$port"
}

soviez_ssh_find_admin_users() {
  # Non-root users with sudo/admin group and a home authorized_keys presence hint.
  local u
  if [[ -f /etc/passwd ]]; then
    while IFS=: read -r u _ uid _ _ home shell; do
      [[ "$uid" -ge 1000 ]] 2>/dev/null || continue
      [[ "$u" == "nobody" ]] && continue
      if [[ -f "${home}/.ssh/authorized_keys" ]] && [[ -s "${home}/.ssh/authorized_keys" ]]; then
        if id -nG "$u" 2>/dev/null | grep -Eq '(sudo|admin|wheel)'; then
          printf '%s\n' "$u"
        fi
      fi
    done < /etc/passwd
  fi
}

soviez_ssh_has_alternate_access() {
  local users
  users="$(soviez_ssh_find_admin_users | head -1 || true)"
  [[ -n "$users" ]]
}

soviez_ssh_sshd_config_test() {
  local conf="${1:-}"
  if command -v sshd >/dev/null 2>&1; then
    mkdir -p /run/sshd 2>/dev/null || true
    if [[ -n "$conf" ]]; then
      sshd -t -f "$conf" >/dev/null 2>&1
    else
      sshd -t >/dev/null 2>&1
    fi
  else
    # Structural: no empty PasswordAuthentication line
    [[ -f "$conf" ]] || return 0
    ! grep -Eq '^[[:space:]]*PasswordAuthentication[[:space:]]*$' "$conf"
  fi
}

soviez_ssh_prepare_dropin() {
  # Write Soviez-owned drop-in fragment (does not apply until verified).
  local out="$1"
  local password_auth="${2:-yes}"
  local permit_root="${3:-prohibit-password}"
  mkdir -p "$(dirname "$out")"
  cat >"$out" <<EOF
# SOVIEZ_OWNED sshd drop-in — Security Gate S2
# Applied only after alternate access verification.
PasswordAuthentication ${password_auth}
PermitRootLogin ${permit_root}
PubkeyAuthentication yes
EOF
  chmod 644 "$out"
}

soviez_ssh_staged_harden() {
  # Safe staged flow. Returns 0 on apply or intentional defer.
  local policy="${SOVIEZ_SSH_POLICY:-staged}"
  local conf="${SOVIEZ_SSH_CONFIG:-/etc/ssh/sshd_config}"
  local dropin="${SOVIEZ_SSH_DROPIN:-/etc/ssh/sshd_config.d/50-soviez-s2.conf}"
  local snap_dir="${SOVIEZ_SSH_SNAPSHOT_DIR:-${TMPDIR:-/tmp}/soviez-ssh-snap-$$}"

  case "$policy" in
    deferred)
      echo "[security] SEC_WARN_SSH_HARDENING_DEFERRED: policy=deferred" >&2
      return 0
      ;;
    staged|keys_required) ;;
    *)
      echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: invalid SSH_POLICY=${policy}" >&2
      return 1
      ;;
  esac

  mkdir -p "$snap_dir"
  chmod 700 "$snap_dir" 2>/dev/null || true
  if [[ -f "$conf" ]]; then
    cp -a "$conf" "$snap_dir/sshd_config.bak" 2>/dev/null || true
  fi
  [[ -f "$dropin" ]] && cp -a "$dropin" "$snap_dir/dropin.bak" 2>/dev/null || true

  if ! soviez_ssh_has_alternate_access; then
    echo "[security] SEC_WARN_SSH_HARDENING_DEFERRED: no verified non-root sudo+key admin" >&2
    if [[ "$policy" == "keys_required" && "${SOVIEZ_SSH_FORCE_UNSAFE:-0}" != "1" ]]; then
      echo "[security] SEC_HIGH_SSH_PASSWORD_AUTH_ENABLED: cannot prove alternate login — deferring" >&2
    fi
    return 0
  fi

  # Prepare hardened drop-in.
  local staged="${dropin}.staged"
  soviez_ssh_prepare_dropin "$staged" "no" "no"

  if [[ "${SOVIEZ_SSH_APPLY:-0}" != "1" ]]; then
    echo "[security] SSH harden prepared at ${staged} (set SOVIEZ_SSH_APPLY=1 to install)" >&2
    return 0
  fi

  if ! soviez_ssh_sshd_config_test "$conf"; then
    echo "[error] security:SEC_HIGH_SSH_PASSWORD_AUTH_ENABLED: sshd -t failed pre-apply" >&2
    rm -f "$staged"
    return 1
  fi
  # Merge test: concatenate main+dropin into temp if sshd supports Include.
  local merged
  merged="$(mktemp)"
  cat "$conf" >"$merged" 2>/dev/null || true
  echo "Include ${staged}" >>"$merged"
  if ! soviez_ssh_sshd_config_test "$merged"; then
    if ! grep -q 'PasswordAuthentication no' "$staged"; then
      rm -f "$staged" "$merged"
      return 1
    fi
  fi
  rm -f "$merged"

  mv -f "$staged" "$dropin"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload sshd >/dev/null 2>&1 || systemctl reload ssh >/dev/null 2>&1 || true
  fi
  return 0
}

soviez_ssh_rollback() {
  local snap_dir="${1:-${SOVIEZ_SSH_SNAPSHOT_DIR:-}}"
  local dropin="${SOVIEZ_SSH_DROPIN:-/etc/ssh/sshd_config.d/50-soviez-s2.conf}"
  [[ -n "$snap_dir" && -d "$snap_dir" ]] || return 1
  if [[ -f "$snap_dir/dropin.bak" ]]; then
    cp -a "$snap_dir/dropin.bak" "$dropin"
  else
    rm -f "$dropin"
  fi
  if [[ -f "$snap_dir/sshd_config.bak" && -n "${SOVIEZ_SSH_CONFIG:-}" ]]; then
    cp -a "$snap_dir/sshd_config.bak" "$SOVIEZ_SSH_CONFIG"
  fi
  command -v systemctl >/dev/null 2>&1 && {
    systemctl reload sshd >/dev/null 2>&1 || systemctl reload ssh >/dev/null 2>&1 || true
  }
  return 0
}
