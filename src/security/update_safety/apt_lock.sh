# shellcheck shell=bash
# S5 Corrective Closure — canonical APT/DPKG lock wait (never kill package managers).
#
# Codes (stdout/structured): PKG_LOCK_WAITING | PKG_LOCK_RELEASED | PKG_LOCK_TIMEOUT
#   | PKG_LOCK_OWNER_UNKNOWN | PKG_STATE_INCONSISTENT | PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED

soviez_pkg_lock_timeout_secs() {
  local t="${SOVIEZ_APT_LOCK_TIMEOUT:-${SOVIEZ_S5_APT_LOCK_TIMEOUT:-120}}"
  [[ "$t" =~ ^[0-9]+$ ]] || t=120
  printf '%s\n' "$t"
}

soviez_pkg_lock_files() {
  printf '%s\n' \
    /var/lib/dpkg/lock-frontend \
    /var/lib/dpkg/lock \
    /var/lib/apt/lists/lock \
    /var/cache/apt/archives/lock
}

# Report lock owners without mutating anything. stdout: "pid|cmd" lines or empty.
soviez_pkg_lock_owners() {
  local f pids pid cmd
  local seen=""
  for f in $(soviez_pkg_lock_files); do
    [[ -e "$f" ]] || continue
    pids=""
    if command -v fuser >/dev/null 2>&1; then
      pids="$(fuser "$f" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' || true)"
    elif command -v lsof >/dev/null 2>&1; then
      pids="$(lsof -t "$f" 2>/dev/null || true)"
    fi
    for pid in $pids; do
      [[ -n "$pid" ]] || continue
      case " $seen " in
        *" $pid "*) continue ;;
      esac
      seen="${seen} ${pid}"
      cmd="$(ps -p "$pid" -o args= 2>/dev/null | head -c 200 || true)"
      # Redact common secret-looking tokens in cmdline.
      cmd="$(printf '%s' "$cmd" | sed -E 's/(password|passwd|token|secret|key)=[^[:space:]]+/\1=***/Ig')"
      printf '%s|%s\n' "$pid" "${cmd:-unknown}"
    done
  done
  # Also surface known package-manager PIDs even if fuser missed lock file.
  local name
  for name in apt apt-get dpkg; do
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      case " $seen " in
        *" $pid "*) continue ;;
      esac
      seen="${seen} ${pid}"
      cmd="$(ps -p "$pid" -o args= 2>/dev/null | head -c 200 || echo "$name")"
      cmd="$(printf '%s' "$cmd" | sed -E 's/(password|passwd|token|secret|key)=[^[:space:]]+/\1=***/Ig')"
      printf '%s|%s\n' "$pid" "$cmd"
    done < <(pgrep -x "$name" 2>/dev/null || true)
  done
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    case " $seen " in
      *" $pid "*) continue ;;
    esac
    seen="${seen} ${pid}"
    cmd="$(ps -p "$pid" -o args= 2>/dev/null | head -c 200 || echo unattended-upgrade)"
    printf '%s|%s\n' "$pid" "$cmd"
  done < <(pgrep -f 'unattended-upgrade' 2>/dev/null || true)
}

soviez_pkg_lock_held() {
  local owners
  owners="$(soviez_pkg_lock_owners)"
  [[ -n "$owners" ]]
}

soviez_pkg_dpkg_inconsistent() {
  # Soft detect: interrupted dpkg / packages needing configure — report only.
  if [[ -f /var/lib/dpkg/updates/tmp.i ]]; then
    return 0
  fi
  if command -v dpkg >/dev/null 2>&1; then
    if dpkg --audit 2>/dev/null | grep -Eqi 'needs reinstall|is unfinished|broken'; then
      return 0
    fi
  fi
  return 1
}

soviez_pkg_lock_report() {
  local code="$1"
  local waited="${2:-0}"
  local owners
  owners="$(soviez_pkg_lock_owners || true)"
  local owner_summary="none"
  if [[ -n "$owners" ]]; then
    owner_summary="$(printf '%s' "$owners" | tr '\n' ';' | head -c 500)"
  else
    code="${code/PKG_LOCK_WAITING/PKG_LOCK_OWNER_UNKNOWN}"
  fi
  SOVIEZ_PKG_CODE="$code" SOVIEZ_PKG_WAIT="$waited" SOVIEZ_PKG_OWNERS="$owner_summary" python3 - <<'PY' 2>/dev/null || \
    printf '{"ok":false,"code":"%s","waited_secs":%s,"owners":"%s"}\n' "$code" "$waited" "$owner_summary"
import json,os
print(json.dumps({
  "ok": os.environ["SOVIEZ_PKG_CODE"] in ("PKG_LOCK_RELEASED",),
  "code": os.environ["SOVIEZ_PKG_CODE"],
  "waited_secs": int(os.environ.get("SOVIEZ_PKG_WAIT") or 0),
  "owners": os.environ.get("SOVIEZ_PKG_OWNERS",""),
  "policy": "wait_only_never_kill",
}, separators=(",",":")))
PY
}

# Canonical wait: detect → report → wait bounded → RELEASED or TIMEOUT.
# Never kill apt/dpkg/unattended-upgrades. Never rm lock files.
soviez_s5_apt_wait_for_lock() {
  local max="${1:-}"
  [[ -n "$max" ]] || max="$(soviez_pkg_lock_timeout_secs)"
  local i=0
  local owners

  if ! soviez_pkg_lock_held; then
    if soviez_pkg_dpkg_inconsistent 2>/dev/null; then
      echo PKG_STATE_INCONSISTENT
      soviez_pkg_lock_report PKG_STATE_INCONSISTENT 0 >&2 || true
      # Inconsistent state is informational — not a lock; caller may continue or guide operator.
      return 0
    fi
    echo PKG_LOCK_RELEASED
    return 0
  fi

  owners="$(soviez_pkg_lock_owners || true)"
  if [[ -z "$owners" ]]; then
    # Lock files may exist without live owner — do NOT delete; wait briefly then re-check processes.
    echo "[security] PKG_LOCK_OWNER_UNKNOWN: lock file present without live holder; waiting safely" >&2
  else
    echo "[security] PKG_LOCK_WAITING: package lock held; waiting up to ${max}s (never killing holders)" >&2
    printf '%s\n' "$owners" | while IFS='|' read -r pid cmd; do
      echo "[security] PKG_LOCK_OWNER pid=${pid} cmd=${cmd}" >&2
    done
  fi

  while (( i < max )); do
    if ! soviez_pkg_lock_held; then
      echo PKG_LOCK_RELEASED
      soviez_pkg_lock_report PKG_LOCK_RELEASED "$i" >&2 || true
      return 0
    fi
    sleep 1
    i=$((i + 1))
    if (( i % 15 == 0 )); then
      echo "[security] PKG_LOCK_WAITING: still held after ${i}s" >&2
    fi
  done

  echo PKG_LOCK_TIMEOUT
  soviez_pkg_lock_report PKG_LOCK_TIMEOUT "$max" >&2 || true
  cat >&2 <<EOF
[error] security:PKG_LOCK_TIMEOUT: package manager lock persisted after ${max}s.
Operation aborted safely. No apt/dpkg/unattended-upgrades process was killed.
No lock files were deleted. Recommended: wait for the listed process to finish,
or schedule maintenance — do NOT run kill -9 against package managers.
EOF
  return 1
}

# Alias used by gates / CLI.
soviez_pkg_wait_for_apt_lock() {
  soviez_s5_apt_wait_for_lock "$@"
}

# Fail-closed if a path still contains destructive heal patterns (supported Production).
soviez_pkg_assert_installer_no_kill() {
  local path="$1"
  if [[ -z "$path" || ! -f "$path" ]]; then
    echo "[error] security:PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED: missing installer ${path:-}" >&2
    echo PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED
    return 1
  fi
  local bad=0
  if grep -nE '^[[:space:]]*killall[[:space:]]+-9[[:space:]]+.*(apt|dpkg|unattended)' "$path" >/dev/null 2>&1; then
    echo "[error] security:PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED: killall -9 package manager in ${path}" >&2
    bad=1
  fi
  if awk '
    /^heal_apt_locks\(/ {infn=1}
    infn && /^[[:space:]]*rm[[:space:]]+-f/ {rm=1}
    infn && rm && /\/var\/lib\/dpkg\/lock|\/var\/lib\/apt\/lists\/lock|\/var\/cache\/apt\/archives\/lock/ {bad=1}
    infn && /^}/ {infn=0; rm=0}
    END { exit bad ? 0 : 1 }
  ' "$path" 2>/dev/null; then
    echo "[error] security:PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED: blind apt/dpkg lock rm in ${path}" >&2
    bad=1
  fi
  if [[ "$bad" -ne 0 ]]; then
    echo PKG_LOCK_UNSAFE_LEGACY_PATH_BLOCKED
    return 1
  fi
  echo SAFE
  return 0
}
