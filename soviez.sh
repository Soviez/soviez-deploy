#!/usr/bin/env bash
# Soviez.sh public bootstrap (customer entry).
# Installs the canonical modular platform payload and stable PATH launcher.
# Does NOT run the legacy unsigned wizard as a public runtime.
# Legacy migration glue (already-installed tenants): see legacy/soviez-wizard.sh
set -euo pipefail

SOVIEZ_BOOTSTRAP_VERSION="0.24.6.0-platform-cli"
SOVIEZ_PLATFORM_CHANNEL="${SOVIEZ_PLATFORM_CHANNEL:-stable}"
SOVIEZ_PLATFORM_ROOT="${SOVIEZ_PLATFORM_ROOT:-/opt/soviez/platform}"
SOVIEZ_PLATFORM_BIN="${SOVIEZ_PLATFORM_BIN:-/usr/local/bin/soviez.sh}"

die() { echo "[error] $*" >&2; exit 1; }
info() { echo "[info] $*"; }

# Unsigned self-update of this bootstrap is retired. Platform updates are signed.
if [[ "${1:-}" == "--legacy-unsigned-update" ]]; then
  die "legacy unsigned updater retired; use signed platform self-update via installed soviez.sh"
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
payload=""

# Prefer adjacent assembled modular payload (repo / installer bundle).
if [[ -n "$here" && -f "${here}/dist/soviez.sh" ]]; then
  payload="${here}/dist/soviez.sh"
elif [[ -n "${SOVIEZ_PLATFORM_INSTALL_SRC:-}" && -f "${SOVIEZ_PLATFORM_INSTALL_SRC}" ]]; then
  payload="${SOVIEZ_PLATFORM_INSTALL_SRC}"
fi

# Connected bootstrap: download signed release artifact via manifest (fail closed on hash).
if [[ -z "$payload" ]]; then
  command -v curl >/dev/null 2>&1 || die "curl required for connected bootstrap"
  command -v python3 >/dev/null 2>&1 || die "python3 required for connected bootstrap"
  man="$(mktemp)"
  cand="$(mktemp)"
  trap 'rm -f "$man" "$cand"' EXIT
  manifest_url="${SOVIEZ_PLATFORM_MANIFEST_URL:-https://raw.githubusercontent.com/Soviez/soviez-deploy/main/platform-release/${SOVIEZ_PLATFORM_CHANNEL}/manifest.json}"
  if [[ -n "${SOVIEZ_PLATFORM_MANIFEST_FILE:-}" && -f "${SOVIEZ_PLATFORM_MANIFEST_FILE}" ]]; then
    cp -f "$SOVIEZ_PLATFORM_MANIFEST_FILE" "$man"
  else
    curl -fsSL --connect-timeout 5 --max-time 60 "$manifest_url" -o "$man" \
      || die "unable to fetch signed platform manifest"
  fi
  artifact_url="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print(m.get("artifact_url") or m.get("url") or "")' "$man")"
  expected="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print((m.get("sha256") or "").replace("sha256:",""))' "$man")"
  [[ -n "$artifact_url" && -n "$expected" ]] || die "manifest missing artifact_url/sha256"
  curl -fsSL --connect-timeout 5 --max-time 180 "$artifact_url" -o "$cand" || die "platform artifact download failed"
  actual="$(shasum -a 256 "$cand" 2>/dev/null | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || die "platform SHA256 mismatch (fail closed)"
  # Optional signature field must be present for connected public bootstrap.
  signed="$(python3 -c 'import json,sys; m=json.load(open(sys.argv[1],encoding="utf-8")); print(str(m.get("signed","")).lower())' "$man")"
  [[ "$signed" == "true" || "$signed" == "1" ]] || die "platform manifest not marked signed (fail closed)"
  payload="$cand"
fi

[[ -f "$payload" ]] || die "modular platform payload not found"

# Install using payload's own installer when available; else minimal copy.
install_root="${SOVIEZ_PLATFORM_ROOT}"
current="${install_root}/current"
previous="${install_root}/previous"
# Absolute paths for launcher (CWD-independent)
case "$install_root" in
  /*) ;;
  *) install_root="$(cd "$install_root" 2>/dev/null && pwd || printf '%s' "$install_root")" ;;
esac
current="${install_root}/current"
previous="${install_root}/previous"
bin_abs="$SOVIEZ_PLATFORM_BIN"
case "$bin_abs" in
  /*) ;;
  *) bin_abs="$(cd "$(dirname "$bin_abs")" 2>/dev/null && pwd)/$(basename "$bin_abs")" ;;
esac
SOVIEZ_PLATFORM_BIN="$bin_abs"
mkdir -p "$current" "$previous" "$(dirname "$SOVIEZ_PLATFORM_BIN")"

if [[ -f "${current}/soviez.sh" ]]; then
  rm -rf "${previous}.bak" 2>/dev/null || true
  if [[ -d "$previous" ]]; then
    mv "$previous" "${previous}.bak" 2>/dev/null || rm -rf "$previous"
  fi
  mkdir -p "$previous"
  cp -a "${current}/." "$previous/" 2>/dev/null || true
fi

cp -f "$payload" "${current}/soviez.sh"
chmod 755 "${current}/soviez.sh"
digest="$(shasum -a 256 "${current}/soviez.sh" | awk '{print $1}')"
printf '%s  soviez.sh\n' "$digest" >"${current}/soviez.sh.sha256"
printf '%s\n' "$SOVIEZ_BOOTSTRAP_VERSION" >"${current}/VERSION"
printf '%s\n' "$SOVIEZ_PLATFORM_CHANNEL" >"${current}/CHANNEL"

cat >"$SOVIEZ_PLATFORM_BIN" <<EOF
#!/usr/bin/env bash
# Soviez.sh stable customer launcher — do not edit.
set -euo pipefail
PAYLOAD="${current}/soviez.sh"
if [[ ! -f "\$PAYLOAD" ]]; then
  echo "[error] Soviez platform payload missing: \$PAYLOAD" >&2
  exit 127
fi
exec bash "\$PAYLOAD" "\$@"
EOF
chmod 755 "$SOVIEZ_PLATFORM_BIN"

info "installed platform → ${current}/soviez.sh"
info "installed launcher → ${SOVIEZ_PLATFORM_BIN}"
info "digest sha256:${digest}"
info "canonical command: soviez.sh (from any directory)"

# If arguments were provided after bootstrap, re-exec through launcher.
if [[ $# -gt 0 ]]; then
  exec env SOVIEZ_SKIP_PLATFORM_UPDATE=1 bash "$SOVIEZ_PLATFORM_BIN" "$@"
fi

echo
echo "Next:"
echo "  soviez.sh --help"
echo "  soviez.sh --version"
echo "  soviez.sh --list"
echo "  soviez.sh --tune --dry-run"
