# shellcheck shell=bash
# Security Gate S5 — package / unattended-upgrades / Docker package policy.

soviez_s5_unattended_upgrades_status() {
  local st="DISABLED"
  if systemctl is-enabled unattended-upgrades >/dev/null 2>&1 \
    || systemctl is-active unattended-upgrades >/dev/null 2>&1; then
    st="ENABLED"
  elif [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    if grep -Eq 'APT::Periodic::(Unattended-Upgrade|Update-Package-Lists).*\"1\"' \
      /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
      st="ENABLED"
    fi
  elif dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
    st="INSTALLED"
  elif [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    st="${SOVIEZ_S5_UA_STATUS:-ABSENT}"
  else
    st="ABSENT"
  fi
  # Policy note: security patches intentional; disruptive service restarts controlled by S5 matrix.
  printf '%s\n' "$st"
}

soviez_s5_apt_lock_healer_safe() {
  # Assert production paths do not blindly kill unattended-upgrades.
  # Returns SAFE (stdout) and exit 0 when no unsafe pattern; UNSAFE otherwise.
  #
  # Confirmed legacy defect (soviez-deploy heal_apt_locks):
  #   force-kill of apt/dpkg/unattended-upgrade holders
  # Impact: mid-flight security updates aborted; package DB risk; surprise disruption.
  # Priority: HIGH (availability + security patch integrity).
  # Production relevance: legacy installer only — must NEVER be ported into soviez-sh.
  # Remediation: wait/backoff only; never kill package managers; defer installer if locked.
  local root="${SOVIEZ_SH_ROOT:-.}"
  local src="$root/src"
  if [[ ! -d "$src" ]]; then
    echo SAFE
    return 0
  fi

  # Scan src only (exclude detector modules — pattern strings live there).
  local hits
  hits="$(grep -RInE \
    --exclude='package_policy.sh' \
    --exclude='apt_lock.sh' \
    'pkill[[:space:]]+(-9[[:space:]]+)?unattended-upgrade|killall[[:space:]]+(-9[[:space:]]+)?unattended-upgrade|kill[[:space:]]+(-9[[:space:]]+).*unattended-upgrade|killall[[:space:]]+-9[[:space:]]+apt' \
    "$src" 2>/dev/null || true)"

  local bad=0
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    case "$line" in
      */docs/*|*evidence*)
        continue
        ;;
      *)
        bad=1
        echo "[error] security:SEC_WARN_REVIEW_REQUIRED: blind unattended-upgrades kill: ${line}" >&2
        ;;
    esac
  done <<<"$hits"

  # Supported dual Production wizard (ERP ↔ soviez-deploy) must also be SAFE.
  local leg erp
  erp="/Volumes/PortableSSD/soviez-project/Soviez ERP/soviez.sh"
  leg="/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh"
  if declare -F soviez_pkg_assert_installer_no_kill >/dev/null 2>&1; then
    for p in "$erp" "$leg"; do
      if [[ -f "$p" ]]; then
        if ! soviez_pkg_assert_installer_no_kill "$p" >/dev/null 2>&1; then
          bad=1
        fi
      fi
    done
  else
    for p in "$erp" "$leg"; do
      [[ -f "$p" ]] || continue
      if grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+apt' "$p" >/dev/null 2>&1; then
        echo "[error] security:PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED: ${p}" >&2
        bad=1
      fi
    done
  fi

  if [[ "$bad" -eq 0 ]]; then
    echo SAFE
    return 0
  fi
  echo UNSAFE
  return 1
}

# Wait implementation lives in update_safety/apt_lock.sh (soviez_s5_apt_wait_for_lock).
# Compatibility shim if apt_lock not yet sourced:
if ! declare -F soviez_s5_apt_wait_for_lock >/dev/null 2>&1; then
  soviez_s5_apt_wait_for_lock() {
    echo "[error] security:PKG_LOCK_OWNER_UNKNOWN: apt_lock.sh not loaded" >&2
    echo PKG_LOCK_OWNER_UNKNOWN
    return 1
  }
fi

soviez_s5_docker_package_update_is_disruptive() {
  # Docker engine/package upgrades commonly disrupt networking/firewall integration.
  # Always true — requires maintenance window + S5 post-validation.
  echo true
  return 0
}
