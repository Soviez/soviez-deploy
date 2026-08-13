#!/usr/bin/env bash
# Soviez Registry Gateway — Ubuntu install (idempotent, fail-safe)
# No Webmin/Virtualmin. Does not reset firewall policy.
# On failure: rolls back to previous install snapshot when available.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}" 2>/dev/null || echo "0.1.0")"

INSTALL_ROOT="${SOVIEZ_RGW_INSTALL_ROOT:-/opt/soviez-registry-gateway}"
CONFIG_DIR="${SOVIEZ_RGW_CONFIG_DIR:-/etc/soviez-registry-gateway}"
STATE_DIR="${SOVIEZ_RGW_STATE_DIR:-/var/lib/soviez-registry-gateway}"
BACKUP_DIR="${STATE_DIR}/backups"
SERVICE_NAME="soviez-registry-gateway"
COMPOSE_BIN=""

log()  { printf '[soviez-rgw-install] %s\n' "$*"; }
warn() { printf '[soviez-rgw-install] WARN: %s\n' "$*" >&2; }
die()  { printf '[soviez-rgw-install] ERROR: %s\n' "$*" >&2; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run as root (sudo). Ubuntu 22.04/24.04 focused."
  fi
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN="docker-compose"
  else
    die "Docker Compose not found. Install Docker Engine + compose plugin first."
  fi
}

preflight() {
  command -v docker >/dev/null 2>&1 || die "docker not found"
  detect_compose
  if ! docker info >/dev/null 2>&1; then
    die "docker daemon not reachable"
  fi
  [[ -f "${SCRIPT_DIR}/compose.yml" ]] || die "compose.yml missing in package"
  [[ -f "${SCRIPT_DIR}/Dockerfile" ]] || die "Dockerfile missing in package"
}

snapshot_existing() {
  mkdir -p "${BACKUP_DIR}"
  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  local dest="${BACKUP_DIR}/pre-install-${stamp}"
  mkdir -p "${dest}"
  if [[ -d "${INSTALL_ROOT}" ]]; then
    log "Snapshotting existing install → ${dest}"
    # Preserve prior tree for rollback; exclude bulky runtime dirs if present
    rsync -a --delete \
      --exclude 'node_modules' \
      --exclude 'dist' \
      --exclude '.install-state' \
      "${INSTALL_ROOT}/" "${dest}/tree/" || true
    if [[ -f "${CONFIG_DIR}/gateway.env" ]]; then
      cp -a "${CONFIG_DIR}/gateway.env" "${dest}/gateway.env"
    fi
    printf '%s\n' "${dest}" > "${STATE_DIR}/last-snapshot"
  else
    printf '' > "${STATE_DIR}/last-snapshot"
  fi
}

rollback() {
  warn "Install failed — attempting rollback"
  local snap=""
  if [[ -f "${STATE_DIR}/last-snapshot" ]]; then
    snap="$(tr -d '[:space:]' < "${STATE_DIR}/last-snapshot")"
  fi
  if [[ -n "${snap}" && -d "${snap}/tree" ]]; then
    log "Restoring tree from ${snap}"
    mkdir -p "${INSTALL_ROOT}"
    rsync -a --delete "${snap}/tree/" "${INSTALL_ROOT}/"
    if [[ -f "${snap}/gateway.env" ]]; then
      mkdir -p "${CONFIG_DIR}"
      cp -a "${snap}/gateway.env" "${CONFIG_DIR}/gateway.env"
    fi
    (
      cd "${INSTALL_ROOT}"
      # shellcheck disable=SC2086
      ${COMPOSE_BIN} -f compose.yml up -d --remove-orphans || true
    )
    warn "Rollback completed from ${snap}. Inspect logs before retrying."
  else
    warn "No prior snapshot; leaving partial state for operator inspection."
    warn "Manual recovery: see docs/RECOVERY.md"
  fi
}

install_tree() {
  mkdir -p "${INSTALL_ROOT}" "${CONFIG_DIR}" "${STATE_DIR}" "${BACKUP_DIR}"
  log "Syncing package → ${INSTALL_ROOT} (version ${VERSION})"
  rsync -a --delete \
    --exclude 'node_modules' \
    --exclude 'dist' \
    --exclude '.git' \
    --exclude '.env' \
    --exclude '.install-state' \
    --exclude 'backups' \
    "${SCRIPT_DIR}/" "${INSTALL_ROOT}/"

  if [[ ! -f "${CONFIG_DIR}/gateway.env" ]]; then
    if [[ -f "${INSTALL_ROOT}/config/gateway.env.example" ]]; then
      cp -a "${INSTALL_ROOT}/config/gateway.env.example" "${CONFIG_DIR}/gateway.env"
      chmod 640 "${CONFIG_DIR}/gateway.env"
      log "Wrote ${CONFIG_DIR}/gateway.env from example — EDIT before production use"
    elif [[ -f "${INSTALL_ROOT}/.env.example" ]]; then
      cp -a "${INSTALL_ROOT}/.env.example" "${CONFIG_DIR}/gateway.env"
      chmod 640 "${CONFIG_DIR}/gateway.env"
    fi
  else
    log "Keeping existing ${CONFIG_DIR}/gateway.env"
  fi

  # Symlink env for Compose env_file convenience when operators run from install root
  if [[ ! -e "${INSTALL_ROOT}/.env" ]]; then
    ln -sfn "${CONFIG_DIR}/gateway.env" "${INSTALL_ROOT}/.env"
  fi

  install -m 644 "${INSTALL_ROOT}/systemd/soviez-registry-gateway.service" \
    /etc/systemd/system/${SERVICE_NAME}.service
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service"

  # Optional nginx site (not enabled automatically — certs are placeholders)
  if [[ -d /etc/nginx/sites-available ]]; then
    install -m 644 "${INSTALL_ROOT}/nginx/registry.soviez.com.conf" \
      /etc/nginx/sites-available/registry.soviez.com.conf
    log "Installed nginx site template (not enabled). Replace CERT_* paths, then:"
    log "  ln -sfn /etc/nginx/sites-available/registry.soviez.com.conf /etc/nginx/sites-enabled/"
    log "  nginx -t && systemctl reload nginx"
  fi
}

start_stack() {
  log "Building and starting Compose stack"
  (
    set -a
    # shellcheck disable=SC1091
    [[ -f "${CONFIG_DIR}/gateway.env" ]] && . "${CONFIG_DIR}/gateway.env"
    set +a
    cd "${INSTALL_ROOT}"
    # shellcheck disable=SC2086
    ${COMPOSE_BIN} -f compose.yml up -d --build --remove-orphans
  )
  systemctl start "${SERVICE_NAME}.service" || true
}

verify() {
  local hc="${INSTALL_ROOT}/healthcheck.sh"
  if [[ -x "${hc}" ]]; then
    "${hc}" || die "Post-install healthcheck failed"
  else
    warn "healthcheck.sh missing; skipping verify"
  fi
}

main() {
  require_root
  preflight
  mkdir -p "${STATE_DIR}"
  trap 'rollback' ERR
  snapshot_existing
  install_tree
  start_stack
  verify
  trap - ERR
  printf '%s\n' "${VERSION}" > "${STATE_DIR}/installed-version"
  log "Install OK — version ${VERSION}"
  log "Public domains: registry.soviez.com (prod), registry-staging.soviez.com (staging)"
  log "Health: GET /live /ready (/health alias). Upstream Hub credentials stay host-local only."
  log "Next: edit ${CONFIG_DIR}/gateway.env, then: systemctl restart ${SERVICE_NAME}"
  log "Docs: ${INSTALL_ROOT}/docs/INSTALLATION.md"
}

main "$@"
