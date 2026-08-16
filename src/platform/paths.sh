# shellcheck shell=bash
# Stable platform layout (customer PATH contract).

SOVIEZ_PLATFORM_ROOT_DEFAULT="/opt/soviez/platform"
SOVIEZ_PLATFORM_BIN_DEFAULT="/usr/local/bin/soviez.sh"
SOVIEZ_PLATFORM_CHANNEL_DEFAULT="stable"

soviez_platform_root() {
  printf '%s\n' "${SOVIEZ_PLATFORM_ROOT:-$SOVIEZ_PLATFORM_ROOT_DEFAULT}"
}

soviez_platform_current_dir() {
  printf '%s/current\n' "$(soviez_platform_root)"
}

soviez_platform_previous_dir() {
  printf '%s/previous\n' "$(soviez_platform_root)"
}

soviez_platform_candidates_dir() {
  printf '%s/candidates\n' "$(soviez_platform_root)"
}

soviez_platform_payload() {
  printf '%s/soviez.sh\n' "$(soviez_platform_current_dir)"
}

soviez_platform_bin() {
  printf '%s\n' "${SOVIEZ_PLATFORM_BIN:-$SOVIEZ_PLATFORM_BIN_DEFAULT}"
}

soviez_platform_lock_path() {
  local root
  root="${SOVIEZ_ROOT:-/var/soviez}"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    root="${SOVIEZ_ROOT}/locks"
    mkdir -p "$root"
    printf '%s/platform-update.lock\n' "$root"
    return 0
  fi
  mkdir -p "${root}/locks" 2>/dev/null || true
  printf '%s/locks/platform-update.lock\n' "$root"
}

soviez_platform_channel() {
  printf '%s\n' "${SOVIEZ_PLATFORM_CHANNEL:-$SOVIEZ_PLATFORM_CHANNEL_DEFAULT}"
}

soviez_platform_digest_file() {
  printf '%s/soviez.sh.sha256\n' "$(soviez_platform_current_dir)"
}

soviez_platform_installed_digest() {
  local f
  f="$(soviez_platform_digest_file)"
  if [[ -f "$f" ]]; then
    awk 'NR==1{print $1; exit}' "$f"
    return 0
  fi
  local payload
  payload="$(soviez_platform_payload)"
  if [[ -f "$payload" ]] && declare -F soviez_sha256_file >/dev/null 2>&1; then
    soviez_sha256_file "$payload"
    return 0
  fi
  if [[ -f "$payload" ]]; then
    shasum -a 256 "$payload" 2>/dev/null | awk '{print $1}' || \
      sha256sum "$payload" 2>/dev/null | awk '{print $1}' || printf 'unknown\n'
    return 0
  fi
  printf 'unknown\n'
}
