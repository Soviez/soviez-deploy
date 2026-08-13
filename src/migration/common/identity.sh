# shellcheck shell=bash

soviez_migration_host_identity() {
  local hn arch os
  hn="$(hostname -f 2>/dev/null || hostname)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
  esac
  os="$(uname -s)"
  SOVIEZ_HN="$hn" SOVIEZ_A="$arch" SOVIEZ_O="$os" python3 - <<'PY'
import hashlib, json, os
raw = f"{os.environ['SOVIEZ_HN']}|{os.environ['SOVIEZ_A']}|{os.environ['SOVIEZ_O']}"
print(json.dumps({
  "hostname": os.environ["SOVIEZ_HN"],
  "architecture": os.environ["SOVIEZ_A"],
  "os_family": os.environ["SOVIEZ_O"],
  "fingerprint": hashlib.sha256(raw.encode()).hexdigest()[:64],
}, separators=(",", ":")))
PY
}

soviez_migration_device_fingerprint() {
  if declare -F soviez_device_fingerprint >/dev/null 2>&1; then
    soviez_device_ensure_keys 2>/dev/null || true
    soviez_device_fingerprint
    return 0
  fi
  printf 'device-unset\n'
}

soviez_migration_detect_os_release() {
  if [[ "${SOVIEZ_MIG_REQUIRE_REAL_HOST:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_FIXTURE_OS_ID 2>/dev/null || true
  elif [[ -n "${SOVIEZ_MIG_FIXTURE_OS_ID:-}" ]]; then
    printf '%s\n' "${SOVIEZ_MIG_FIXTURE_OS_ID}"
    return 0
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s:%s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
    return 0
  fi
  # Darwin host used for unit fixtures — not a supported destination OS
  printf 'darwin:unknown\n'
}

soviez_migration_detect_arch() {
  if [[ "${SOVIEZ_MIG_REQUIRE_REAL_HOST:-0}" == "1" ]]; then
    unset SOVIEZ_MIG_FIXTURE_ARCH 2>/dev/null || true
  elif [[ -n "${SOVIEZ_MIG_FIXTURE_ARCH:-}" ]]; then
    printf '%s\n' "$SOVIEZ_MIG_FIXTURE_ARCH"
    return 0
  fi
  local a
  a="$(uname -m)"
  case "$a" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) printf '%s\n' "$a" ;;
  esac
}

soviez_migration_os_supported() {
  local idver="$1"
  case "$idver" in
    ubuntu:22.04|ubuntu:24.04) return 0 ;;
    *) return 1 ;;
  esac
}

soviez_migration_arch_supported() {
  [[ "$1" == "amd64" ]]
}
