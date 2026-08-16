# shellcheck shell=bash
# Install modular platform payload + stable PATH launcher.

soviez_platform_render_launcher() {
  local payload_path="$1"
  # Always embed an absolute payload path so CWD does not matter.
  if command -v realpath >/dev/null 2>&1; then
    payload_path="$(realpath "$payload_path" 2>/dev/null || printf '%s' "$payload_path")"
  elif [[ "${payload_path}" != /* ]]; then
    payload_path="$(cd "$(dirname "$payload_path")" 2>/dev/null && pwd)/$(basename "$payload_path")"
  fi
  cat <<EOF
#!/usr/bin/env bash
# Soviez.sh stable customer launcher — do not edit.
# Delegates to the active platform payload.
set -euo pipefail
PAYLOAD="${payload_path}"
if [[ ! -x "\$PAYLOAD" && ! -f "\$PAYLOAD" ]]; then
  echo "[error] Soviez platform payload missing: \$PAYLOAD" >&2
  echo "Re-run the official installer: curl -sSL https://soviez.sh | sudo bash" >&2
  exit 127
fi
exec bash "\$PAYLOAD" "\$@"
EOF
}

soviez_platform_install_from_file() {
  local src="$1"
  local channel="${2:-$(soviez_platform_channel)}"
  [[ -f "$src" ]] || {
    echo "[error] platform install source missing: $src" >&2
    return 1
  }

  local root current previous candidates bin tmpdir digest payload_dest launcher_tmp
  root="$(soviez_platform_root)"
  current="$(soviez_platform_current_dir)"
  previous="$(soviez_platform_previous_dir)"
  candidates="$(soviez_platform_candidates_dir)"
  bin="$(soviez_platform_bin)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    root="${SOVIEZ_ROOT}/platform"
    current="${root}/current"
    previous="${root}/previous"
    candidates="${root}/candidates"
    bin="${SOVIEZ_ROOT}/bin/soviez.sh"
    mkdir -p "${SOVIEZ_ROOT}/bin"
  fi

  mkdir -p "$current" "$previous" "$candidates"
  # Install trust public keys alongside payload (never private keys).
  local trust_src=""
  if [[ -d "${SOVIEZ_SH_ROOT:-}/share/platform-trust" ]]; then
    trust_src="${SOVIEZ_SH_ROOT}/share/platform-trust"
  elif [[ -d "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../share/platform-trust" 2>/dev/null && pwd)" ]]; then
    trust_src="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../share/platform-trust" && pwd)"
  fi
  if [[ -z "$trust_src" && -d "${SOVIEZ_PLATFORM_TRUST_DIR:-}" ]]; then
    trust_src="$SOVIEZ_PLATFORM_TRUST_DIR"
  fi
  tmpdir="$(mktemp -d "${candidates}/install.XXXXXX")"
  cp -f "$src" "${tmpdir}/soviez.sh"
  chmod 755 "${tmpdir}/soviez.sh"
  if [[ -n "$trust_src" && -d "$trust_src" ]]; then
    mkdir -p "${tmpdir}/trust"
    # Public material only
    cp -f "$trust_src"/*.pub "${tmpdir}/trust/" 2>/dev/null || true
    cp -f "$trust_src"/keys.json "${tmpdir}/trust/" 2>/dev/null || true
    # Refuse any private key leakage into install tree
    if grep -Rql 'BEGIN PRIVATE KEY' "${tmpdir}/trust" 2>/dev/null; then
      echo "[error] refused to install trust tree containing private key material" >&2
      rm -rf "$tmpdir"
      return 1
    fi
  fi
  if declare -F soviez_sha256_file >/dev/null 2>&1; then
    digest="$(soviez_sha256_file "${tmpdir}/soviez.sh")"
  else
    digest="$(shasum -a 256 "${tmpdir}/soviez.sh" 2>/dev/null | awk '{print $1}')"
  fi
  printf '%s  soviez.sh\n' "$digest" >"${tmpdir}/soviez.sh.sha256"
  printf '%s\n' "$(soviez_version 2>/dev/null || echo unknown)" >"${tmpdir}/VERSION"
  printf '%s\n' "$channel" >"${tmpdir}/CHANNEL"

  # Rotate current → previous when replacing.
  if [[ -f "${current}/soviez.sh" ]]; then
    rm -rf "${previous}.bak" 2>/dev/null || true
    if [[ -d "$previous" ]]; then
      mv "$previous" "${previous}.bak" 2>/dev/null || rm -rf "$previous"
    fi
    mkdir -p "$previous"
    cp -a "${current}/." "$previous/" 2>/dev/null || true
  fi

  payload_dest="${current}/soviez.sh"
  cp -f "${tmpdir}/soviez.sh" "$payload_dest"
  cp -f "${tmpdir}/soviez.sh.sha256" "${current}/soviez.sh.sha256"
  cp -f "${tmpdir}/VERSION" "${current}/VERSION"
  cp -f "${tmpdir}/CHANNEL" "${current}/CHANNEL"
  if [[ -d "${tmpdir}/trust" ]]; then
    mkdir -p "${current}/trust"
    cp -a "${tmpdir}/trust/." "${current}/trust/"
  fi
  chmod 755 "$payload_dest"
  rm -rf "$tmpdir" "${previous}.bak" 2>/dev/null || true

  mkdir -p "$(dirname "$bin")"
  launcher_tmp="$(mktemp "${TMPDIR:-/tmp}/soviez-launcher.XXXXXX")"
  soviez_platform_render_launcher "$payload_dest" >"$launcher_tmp"
  chmod 755 "$launcher_tmp"
  mv -f "$launcher_tmp" "$bin"
  chmod 755 "$bin"

  echo "[ok] installed platform payload → ${payload_dest}"
  echo "[ok] installed launcher → ${bin}"
  echo "[ok] digest sha256:${digest}"
}

# Convenience: install currently executing assembled script as platform (when run from dist).
soviez_platform_install_self_payload() {
  local self="${BASH_SOURCE[0]:-${0:-}}"
  # When assembled, BASH_SOURCE[0] is the dist script path for functions defined in it —
  # prefer SOVIEZ_PLATFORM_INSTALL_SRC or the running $0 when it is the payload.
  local src="${SOVIEZ_PLATFORM_INSTALL_SRC:-}"
  if [[ -z "$src" ]]; then
    if [[ -f "${0:-}" && "$(basename -- "${0}")" == "soviez.sh" ]]; then
      src="$0"
    elif [[ -f "${SOVIEZ_SH_ROOT:-}/dist/soviez.sh" ]]; then
      src="${SOVIEZ_SH_ROOT}/dist/soviez.sh"
    else
      echo "[error] cannot locate platform payload to install" >&2
      return 1
    fi
  fi
  soviez_platform_install_from_file "$src" "$(soviez_platform_channel)"
}
