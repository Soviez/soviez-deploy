#!/usr/bin/env bash
# Soviez Registry Gateway — uninstall (fail-safe; preserves config unless --purge)
set -euo pipefail

INSTALL_ROOT="${SOVIEZ_RGW_INSTALL_ROOT:-/opt/soviez-registry-gateway}"
CONFIG_DIR="${SOVIEZ_RGW_CONFIG_DIR:-/etc/soviez-registry-gateway}"
STATE_DIR="${SOVIEZ_RGW_STATE_DIR:-/var/lib/soviez-registry-gateway}"
SERVICE_NAME="soviez-registry-gateway"
PURGE=0

log()  { printf '[soviez-rgw-uninstall] %s\n' "$*"; }
warn() { printf '[soviez-rgw-uninstall] WARN: %s\n' "$*" >&2; }
die()  { printf '[soviez-rgw-uninstall] ERROR: %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "${arg}" in
    --purge) PURGE=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: uninstall.sh [--purge]

Stops Compose stack and disables systemd unit.
Without --purge: keeps /etc/soviez-registry-gateway and backups under state dir.
With --purge: also removes config, install tree, and state (irreversible).
Does not modify firewall rules or unrelated packages.
EOF
      exit 0
      ;;
    *) die "Unknown argument: ${arg}" ;;
  esac
done

[[ "${EUID}" -eq 0 ]] || die "Run as root (sudo)."

COMPOSE_BIN=""
if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BIN="docker-compose"
fi

if systemctl list-unit-files "${SERVICE_NAME}.service" >/dev/null 2>&1; then
  systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
  systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
fi

if [[ -n "${COMPOSE_BIN}" && -f "${INSTALL_ROOT}/compose.yml" ]]; then
  log "Stopping Compose stack"
  (
    cd "${INSTALL_ROOT}"
    # shellcheck disable=SC2086
    ${COMPOSE_BIN} -f compose.yml down --remove-orphans || true
  )
fi

rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload || true

if [[ -f /etc/nginx/sites-enabled/registry.soviez.com.conf ]]; then
  warn "Leaving nginx site enabled file in place — disable manually if desired:"
  warn "  rm -f /etc/nginx/sites-enabled/registry.soviez.com.conf && nginx -t && systemctl reload nginx"
fi

if [[ "${PURGE}" -eq 1 ]]; then
  log "Purging install tree, config, and state"
  rm -rf "${INSTALL_ROOT}" "${CONFIG_DIR}" "${STATE_DIR}"
  rm -f /etc/nginx/sites-available/registry.soviez.com.conf
else
  log "Leaving ${CONFIG_DIR} and ${STATE_DIR} intact (use --purge to remove)"
  # Remove code tree but keep backups if nested under state
  if [[ -d "${INSTALL_ROOT}" ]]; then
    rm -rf "${INSTALL_ROOT}"
  fi
fi

log "Uninstall complete"
