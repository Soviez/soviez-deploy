#!/usr/bin/env bash
# Soviez Registry Gateway — update (idempotent; snapshots before replace)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${SOVIEZ_RGW_INSTALL_ROOT:-/opt/soviez-registry-gateway}"
CONFIG_DIR="${SOVIEZ_RGW_CONFIG_DIR:-/etc/soviez-registry-gateway}"
STATE_DIR="${SOVIEZ_RGW_STATE_DIR:-/var/lib/soviez-registry-gateway}"
SERVICE_NAME="soviez-registry-gateway"

log()  { printf '[soviez-rgw-update] %s\n' "$*"; }
warn() { printf '[soviez-rgw-update] WARN: %s\n' "$*" >&2; }
die()  { printf '[soviez-rgw-update] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die "Run as root (sudo)."
[[ -x "${SCRIPT_DIR}/install.sh" ]] || die "install.sh missing next to update.sh"

PREV=""
if [[ -f "${STATE_DIR}/installed-version" ]]; then
  PREV="$(tr -d '[:space:]' < "${STATE_DIR}/installed-version")"
fi
NEW="$(tr -d '[:space:]' < "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo unknown)"
log "Updating ${PREV:-none} → ${NEW}"

# Re-use install.sh (snapshots + rollback on ERR)
"${SCRIPT_DIR}/install.sh"

log "Update finished. If health fails, restore last snapshot under ${STATE_DIR}/backups/"
log "See docs/UPGRADE.md and docs/RECOVERY.md"
