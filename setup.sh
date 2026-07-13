#!/usr/bin/env bash
# Soviez ERP — production onboarding wizard (Ubuntu/Debian)
#
# Modes:
#   ./setup.sh            | --init    Host environment bootstrap (apt, Docker, Nginx, Certbot, UFW)
#   ./setup.sh --new                  Provision isolated multi-tenant instance + DNS/SSL/addons
#   ./setup.sh --formsetup            Resume / heal the latest half-configured tenant (idempotent)
#   ./setup.sh --update               Pull soviez/soviez-erp:latest and recycle web runners
#   ./setup.sh --recoverdbpass        Rotate Database Master Password (primary / indexed via env)
#
# Logs: /var/log/soviez_setup.log (verbose); terminal shows clean status UI only.
set -euo pipefail

readonly APP_IMAGE="soviez/soviez-erp:latest"
readonly DB_IMAGE="postgres:16"
readonly UPGRADE_MODULES="base,local_license_guard,mail,web,web_enterprise,soviez_web_ui"
readonly PORT_SCAN_MAX=8999
readonly PRIMARY_PORT_START=8069
readonly MULTI_PORT_START=8073
readonly CUSTOM_ADDONS_CONTAINER_PATH="/var/lib/odoo/custom_addons"
LOG_FILE="/var/log/soviez_setup.log"
readonly NGINX_LIMITS_CONF="/etc/nginx/conf.d/soviez_limits.conf"

# Mutable topology (overridden by apply_topology_*)
ENV_FILE=".soviez.env"
NETWORK_NAME="soviez_network"
DB_CONTAINER="soviez-db"
WEB_CONTAINER="soviez-web"
DB_VOLUME="soviez_db_data"
FILESTORE_VOLUME="soviez_filestore"
INSTANCE_INDEX=""
PORT_SCAN_START="${PRIMARY_PORT_START}"
CUSTOM_ADDONS_HOST_PATH=""
TENANT_DOMAIN=""

# ---------------------------------------------------------------------------
# Colors / UI
# ---------------------------------------------------------------------------
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_DIM=$'\033[2m'
readonly C_GREEN=$'\033[0;32m'
readonly C_YELLOW=$'\033[0;33m'
readonly C_RED=$'\033[0;31m'
readonly C_CYAN=$'\033[0;36m'
readonly C_BLUE=$'\033[0;34m'

# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------
MODE="init"
for arg in "$@"; do
  case "${arg}" in
    --init)
      MODE="init"
      ;;
    --update)
      MODE="update"
      ;;
    --new)
      MODE="new"
      ;;
    --formsetup)
      MODE="formsetup"
      ;;
    --recoverdbpass)
      MODE="recover"
      ;;
    -h|--help)
      cat <<'USAGE'
Soviez ERP — production onboarding wizard

Usage:
  ./setup.sh [--init]         Bootstrap host (apt, Docker, Nginx, Certbot, UFW)
  ./setup.sh --new            Provision a new isolated tenant (domain + SSL + addons)
  ./setup.sh --formsetup      Resume / heal latest half-configured tenant (idempotent)
  ./setup.sh --update         Pull latest ERP image and recycle web containers
  ./setup.sh --recoverdbpass  Rotate Database Master Password
  ./setup.sh --help           Show this help

Images:
  soviez/soviez-erp:latest
  postgres:16

Verbose log:
  /var/log/soviez_setup.log
USAGE
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: ${arg}" >&2
      echo "[ERROR] Try: ./setup.sh --help" >&2
      exit 1
      ;;
  esac
done

umask 077

# ---------------------------------------------------------------------------
# Logging → file; clean UI → terminal
# ---------------------------------------------------------------------------
ensure_log_file() {
  # Prefer /var/log when root; otherwise fall back to instance ledger / tmp.
  if [[ "${EUID}" -eq 0 ]]; then
    touch "${LOG_FILE}" 2>/dev/null || true
    chmod 640 "${LOG_FILE}" 2>/dev/null || true
    return 0
  fi
  if [[ -d "${HOST_SOVIEZ_DIR:-}" ]] || mkdir -p "${HOST_SOVIEZ_DIR:-${HOME}/.soviez}" 2>/dev/null; then
    LOG_FILE="${HOST_SOVIEZ_DIR:-${HOME}/.soviez}/soviez_setup.log"
  else
    LOG_FILE="/tmp/soviez_setup.log"
  fi
  touch "${LOG_FILE}" 2>/dev/null || true
}

log_file() {
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf '[%s] %s\n' "${ts}" "$*" >> "${LOG_FILE}" 2>/dev/null || true
}

ui_info()  { echo -e "${C_CYAN}[INFO]${C_RESET} $*"; log_file "INFO  $*"; }
ui_ok()    { echo -e "${C_GREEN}[OK]${C_RESET}   $*"; log_file "OK    $*"; }
ui_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; log_file "WARN  $*"; }
ui_error() { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; log_file "ERROR $*"; }
ui_wait()  { echo -e "${C_BLUE}[WAIT]${C_RESET} $*"; log_file "WAIT  $*"; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    ui_error "This mode requires root. Re-run with: sudo ./setup.sh $*"
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    ui_error "Required command not found: $1"
    exit 1
  fi
}

# Spinner + silent command runner (stdout/stderr → log)
show_progress() {
  local message="$1"
  shift
  local -a cmd=("$@")
  local spin='|/-\\'
  local i=0
  local pid
  local rc=0

  ensure_log_file
  ui_wait "${message}"
  log_file "EXEC  ${cmd[*]}"

  # Run in a subshell so shell functions work; keep spinner on TTY.
  (
    "${cmd[@]}"
  ) >>"${LOG_FILE}" 2>&1 &
  pid=$!

  if [[ -t 1 ]]; then
    while kill -0 "${pid}" 2>/dev/null; do
      printf '\r%s[WAIT]%s %s %s' "${C_BLUE}" "${C_RESET}" "${message}" "${spin:i++%${#spin}:1}"
      sleep 0.12
    done
    printf '\r\033[K'
  fi

  set +e
  wait "${pid}"
  rc=$?
  set -e

  if (( rc == 0 )); then
    ui_ok "${message}"
  else
    ui_error "${message} (failed — see ${LOG_FILE})"
  fi
  return "${rc}"
}

run_quiet() {
  log_file "EXEC  $*"
  "$@" >>"${LOG_FILE}" 2>&1
}

print_border_box() {
  local title="$1"
  shift
  local line
  echo ""
  echo -e "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}║${C_RESET}  ${C_BOLD}${title}${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}╠══════════════════════════════════════════════════════════════════════╣${C_RESET}"
  for line in "$@"; do
    echo -e "${C_BOLD}${C_CYAN}║${C_RESET}  ${line}"
  done
  echo -e "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
}

print_green_success() {
  echo ""
  echo -e "${C_GREEN}${C_BOLD}==============================================================${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}  $*${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}==============================================================${C_RESET}"
  echo ""
}

print_master_password_alert() {
  local password="$1"
  local headline="${2:-DATABASE MASTER PASSWORD}"
  echo ""
  echo -e "${C_RED}${C_BOLD}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${C_RESET}"
  echo -e "${C_RED}${C_BOLD}!!  ${headline}${C_RESET}"
  echo -e "${C_RED}${C_BOLD}!!  ${password}${C_RESET}"
  echo -e "${C_RED}${C_BOLD}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${C_RESET}"
  echo -e "${C_RED}Copy and vault this password now. Required for the Web Database Manager.${C_RESET}"
  echo -e "${C_DIM}Recover later: sudo ./setup.sh --recoverdbpass${C_RESET}"
  echo ""
}

# ---------------------------------------------------------------------------
# Paths / topology
# ---------------------------------------------------------------------------
resolve_instance_root() {
  if [[ -n "${SOVIEZ_INSTANCE_ROOT:-}" ]]; then
    printf '%s\n' "${SOVIEZ_INSTANCE_ROOT}"
    return 0
  fi
  if [[ -d /root && -w /root ]]; then
    printf '%s\n' "/root"
    return 0
  fi
  printf '%s\n' "$(pwd)"
}

resolve_host_soviez_dir() {
  if [[ -n "${SOVIEZ_HOST_LEDGER_DIR:-}" ]]; then
    printf '%s\n' "${SOVIEZ_HOST_LEDGER_DIR}"
    return 0
  fi
  if [[ -n "${HOME:-}" ]]; then
    printf '%s\n' "${HOME}/.soviez"
    return 0
  fi
  if [[ -d /root ]]; then
    printf '%s\n' "/root/.soviez"
    return 0
  fi
  printf '%s\n' "$(pwd)/.soviez"
}

INSTANCE_ROOT="$(resolve_instance_root)"
HOST_SOVIEZ_DIR="$(resolve_host_soviez_dir)"

ensure_host_ledger_dir() {
  mkdir -p "${HOST_SOVIEZ_DIR}"
  chmod 700 "${HOST_SOVIEZ_DIR}"
  log_file "Host ledger ready: ${HOST_SOVIEZ_DIR}"
}

is_port_busy() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    if ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .; then
      return 0
    fi
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
      return 0
    fi
    return 1
  fi
  if command -v netstat >/dev/null 2>&1; then
    if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
      return 0
    fi
    return 1
  fi
  if (echo >/dev/tcp/127.0.0.1/"${port}") >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

find_free_host_port() {
  local start="${1:-${PORT_SCAN_START}}"
  local port="${start}"
  while (( port <= PORT_SCAN_MAX )); do
    if is_port_busy "${port}"; then
      log_file "Port ${port} busy — probing next"
      port=$((port + 1))
    else
      echo "${port}"
      return 0
    fi
  done
  ui_error "No free TCP port in range ${start}-${PORT_SCAN_MAX}."
  return 1
}

generate_mac() {
  python3 - <<'PY'
import secrets
octets = [secrets.randbelow(256) for _ in range(3)]
print("02:42:ac:" + ":".join(f"{b:02x}" for b in octets))
PY
}

generate_password() {
  python3 - <<'PY'
import secrets
import string
alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(32)))
PY
}

persist_env_key() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "${ENV_FILE}" ]]; then
    grep -v "^${key}=" "${ENV_FILE}" > "${tmp}" || true
  else
    : > "${tmp}"
  fi
  echo "${key}=${value}" >> "${tmp}"
  mv "${tmp}" "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
}

load_env_file() {
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
}

container_exists() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -Fxq "$1"
}

container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -Fxq "$1"
}

apply_topology_primary() {
  ENV_FILE="$(pwd)/.soviez.env"
  if [[ -f "${INSTANCE_ROOT}/.soviez.env" ]]; then
    ENV_FILE="${INSTANCE_ROOT}/.soviez.env"
  elif [[ ! -f "${ENV_FILE}" && -f ".soviez.env" ]]; then
    ENV_FILE="$(pwd)/.soviez.env"
  fi
  NETWORK_NAME="soviez_network"
  DB_CONTAINER="soviez-db"
  WEB_CONTAINER="soviez-web"
  DB_VOLUME="soviez_db_data"
  FILESTORE_VOLUME="soviez_filestore"
  INSTANCE_INDEX=""
  CUSTOM_ADDONS_HOST_PATH=""
  PORT_SCAN_START="${PRIMARY_PORT_START}"
}

apply_topology_indexed() {
  local index="$1"
  INSTANCE_INDEX="${index}"
  ENV_FILE="${INSTANCE_ROOT}/.soviez_${index}.env"
  NETWORK_NAME="soviez_network_${index}"
  DB_CONTAINER="soviez-db-${index}"
  WEB_CONTAINER="soviez-web-${index}"
  DB_VOLUME="soviez_db_data_${index}"
  FILESTORE_VOLUME="soviez_filestore_${index}"
  CUSTOM_ADDONS_HOST_PATH="/etc/soviez_web_${index}/addons"
  PORT_SCAN_START="${MULTI_PORT_START}"
}

find_next_instance_index() {
  local max=0
  local path base num

  shopt -s nullglob
  for path in \
      "${INSTANCE_ROOT}"/.soviez_*.env \
      "$(pwd)"/.soviez_*.env; do
    [[ -f "${path}" ]] || continue
    base="$(basename "${path}")"
    if [[ "${base}" =~ ^\.soviez_([0-9]+)\.env$ ]]; then
      num="${BASH_REMATCH[1]}"
      if (( num > max )); then
        max="${num}"
      fi
    fi
  done
  shopt -u nullglob

  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    if [[ "${name}" =~ ^soviez-web-([0-9]+)$ ]]; then
      num="${BASH_REMATCH[1]}"
      if (( num > max )); then
        max="${num}"
      fi
    fi
  done < <(docker ps -a --format '{{.Names}}' 2>/dev/null || true)

  if (( max >= 1 )); then
    echo $((max + 1))
  else
    echo 1
  fi
}

# Highest existing indexed env sheet (0 = none). Does not +1.
find_highest_instance_index() {
  local max=0
  local path base num

  shopt -s nullglob
  for path in \
      "${INSTANCE_ROOT}"/.soviez_*.env \
      "$(pwd)"/.soviez_*.env; do
    [[ -f "${path}" ]] || continue
    base="$(basename "${path}")"
    if [[ "${base}" =~ ^\.soviez_([0-9]+)\.env$ ]]; then
      num="${BASH_REMATCH[1]}"
      if (( num > max )); then
        max="${num}"
      fi
    fi
  done
  shopt -u nullglob
  echo "${max}"
}

# True when domain Nginx vhost, enabled symlink, and/or Let's Encrypt cert look unfinished.
tenant_proxy_incomplete() {
  local domain="$1"
  local site_file="/etc/nginx/sites-available/soviez-${domain}.conf"
  local enabled_link="/etc/nginx/sites-enabled/soviez-${domain}.conf"
  local cert_file="/etc/letsencrypt/live/${domain}/fullchain.pem"

  [[ -z "${domain}" ]] && return 0
  [[ ! -f "${site_file}" ]] && return 0
  [[ ! -e "${enabled_link}" ]] && return 0
  [[ ! -f "${cert_file}" ]] && return 0
  return 1
}

# Prefer highest half-configured tenant; else newest env sheet.
select_formsetup_index() {
  local max path domain
  local i
  local site_incomplete

  max="$(find_highest_instance_index)"
  if (( max < 1 )); then
    echo 0
    return 0
  fi

  for (( i = max; i >= 1; i-- )); do
    path=""
    for candidate in "${INSTANCE_ROOT}/.soviez_${i}.env" "$(pwd)/.soviez_${i}.env"; do
      if [[ -f "${candidate}" ]]; then
        path="${candidate}"
        break
      fi
    done
    [[ -n "${path}" ]] || continue

    domain="$(grep -E '^SOVIEZ_TENANT_DOMAIN=' "${path}" 2>/dev/null | head -n1 | cut -d= -f2- || true)"
    site_incomplete=0
    if tenant_proxy_incomplete "${domain}"; then
      site_incomplete=1
    fi
    if (( site_incomplete == 1 )) \
        || ! container_exists "soviez-db-${i}" \
        || ! container_running "soviez-db-${i}" \
        || ! container_exists "soviez-web-${i}" \
        || ! container_running "soviez-web-${i}"; then
      log_file "formsetup: selected incomplete index=${i} domain=${domain:-?} env=${path}"
      echo "${i}"
      return 0
    fi
  done

  log_file "formsetup: no incomplete tenant — resuming highest index=${max}"
  echo "${max}"
}

# ---------------------------------------------------------------------------
# Docker / DB / web lifecycle (shared by --new / --formsetup / --update / --recover)
# ---------------------------------------------------------------------------
docker_network_exists() {
  docker network inspect "$1" >/dev/null 2>&1
}

docker_volume_exists() {
  docker volume inspect "$1" >/dev/null 2>&1
}

ensure_network_and_volumes() {
  if docker_network_exists "${NETWORK_NAME}"; then
    log_file "Network ${NETWORK_NAME} already exists"
  else
    docker network create "${NETWORK_NAME}" >>"${LOG_FILE}" 2>&1
  fi
  if docker_volume_exists "${DB_VOLUME}"; then
    log_file "Volume ${DB_VOLUME} already exists"
  else
    docker volume create "${DB_VOLUME}" >/dev/null
  fi
  if docker_volume_exists "${FILESTORE_VOLUME}"; then
    log_file "Volume ${FILESTORE_VOLUME} already exists"
  else
    docker volume create "${FILESTORE_VOLUME}" >/dev/null
  fi
}

# Idempotent resume path with tidy terminal OK lines (used by --formsetup).
resume_network_and_volumes() {
  ui_wait "Checking Docker network and volumes for ${NETWORK_NAME}..."
  local created=0
  if docker_network_exists "${NETWORK_NAME}"; then
    log_file "Network ${NETWORK_NAME} already present"
  else
    docker network create "${NETWORK_NAME}" >>"${LOG_FILE}" 2>&1
    created=1
  fi
  if docker_volume_exists "${DB_VOLUME}"; then
    log_file "Volume ${DB_VOLUME} already present"
  else
    docker volume create "${DB_VOLUME}" >/dev/null
    created=1
  fi
  if docker_volume_exists "${FILESTORE_VOLUME}"; then
    log_file "Volume ${FILESTORE_VOLUME} already present"
  else
    docker volume create "${FILESTORE_VOLUME}" >/dev/null
    created=1
  fi
  if (( created == 0 )); then
    ui_ok "Volumes already present"
  else
    ui_ok "Network and volumes ready"
  fi
}

wait_for_postgres() {
  local i
  for i in $(seq 1 45); do
    if docker exec "${DB_CONTAINER}" pg_isready -U soviez -d postgres >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  ui_error "PostgreSQL did not become ready. Inspect: docker logs ${DB_CONTAINER}"
  return 1
}

ensure_postgres_container() {
  if container_running "${DB_CONTAINER}"; then
    log_file "DB ${DB_CONTAINER} already running"
  elif container_exists "${DB_CONTAINER}"; then
    docker start "${DB_CONTAINER}" >/dev/null
  else
    docker run -d \
      --name "${DB_CONTAINER}" \
      --restart unless-stopped \
      --network "${NETWORK_NAME}" \
      -e POSTGRES_DB=postgres \
      -e POSTGRES_USER=soviez \
      -e POSTGRES_PASSWORD="${SOVIEZ_DB_PASSWORD}" \
      -e PASSWORD="${SOVIEZ_DB_PASSWORD}" \
      -v "${DB_VOLUME}:/var/lib/postgresql/data" \
      "${DB_IMAGE}" >/dev/null
  fi
  wait_for_postgres
}

resume_postgres_container() {
  if container_running "${DB_CONTAINER}"; then
    ui_ok "PostgreSQL already running (${DB_CONTAINER})"
    wait_for_postgres
    return 0
  fi
  if container_exists "${DB_CONTAINER}"; then
    ui_wait "Starting stopped PostgreSQL (${DB_CONTAINER})..."
    docker start "${DB_CONTAINER}" >>"${LOG_FILE}" 2>&1
    wait_for_postgres
    ui_ok "PostgreSQL started (${DB_CONTAINER})"
    return 0
  fi
  ui_wait "Creating PostgreSQL (${DB_CONTAINER})..."
  ensure_postgres_container
  ui_ok "PostgreSQL created (${DB_CONTAINER})"
}

resume_web_container() {
  if container_running "${WEB_CONTAINER}"; then
    ui_ok "Web ERP already running (${WEB_CONTAINER})"
    return 0
  fi
  if container_exists "${WEB_CONTAINER}"; then
    ui_wait "Starting stopped web ERP (${WEB_CONTAINER})..."
    docker start "${WEB_CONTAINER}" >>"${LOG_FILE}" 2>&1
    ui_ok "Web ERP started (${WEB_CONTAINER})"
    return 0
  fi
  ui_wait "Creating web ERP (${WEB_CONTAINER})..."
  launch_web_container
  ui_ok "Web ERP created (${WEB_CONTAINER})"
}

ensure_custom_addons_dir() {
  if [[ -z "${CUSTOM_ADDONS_HOST_PATH}" ]]; then
    return 0
  fi
  mkdir -p "${CUSTOM_ADDONS_HOST_PATH}"
  chmod 755 "$(dirname "${CUSTOM_ADDONS_HOST_PATH}")" 2>/dev/null || true
  chmod 755 "${CUSTOM_ADDONS_HOST_PATH}"
  # Friendly README on first create
  if [[ ! -f "${CUSTOM_ADDONS_HOST_PATH}/README.txt" ]]; then
    cat > "${CUSTOM_ADDONS_HOST_PATH}/README.txt" <<EOF
Soviez ERP — custom addons drop folder for ${WEB_CONTAINER}

Place Odoo/Soviez modules here (each module in its own subdirectory).
They are mounted read/write into the container at:
  ${CUSTOM_ADDONS_CONTAINER_PATH}

After dropping a module, update the database apps list from the UI
or run: sudo ./setup.sh --update
EOF
  fi
}

launch_web_container() {
  local addons_cli
  local -a volume_args=()

  ensure_host_ledger_dir
  ensure_custom_addons_dir

  volume_args+=(
    -v "${FILESTORE_VOLUME}:/root/.local/share/Odoo/filestore"
    -v "${HOST_SOVIEZ_DIR}:/root/.soviez"
  )

  addons_cli="/opt/soviez-erp/addons,/opt/soviez-erp/odoo/addons"
  if [[ -n "${CUSTOM_ADDONS_HOST_PATH}" ]]; then
    volume_args+=(
      -v "${CUSTOM_ADDONS_HOST_PATH}:${CUSTOM_ADDONS_CONTAINER_PATH}"
    )
    addons_cli="${addons_cli},${CUSTOM_ADDONS_CONTAINER_PATH}"
  fi

  docker run -d \
    --name "${WEB_CONTAINER}" \
    --restart unless-stopped \
    --network "${NETWORK_NAME}" \
    --mac-address "${SOVIEZ_CONTAINER_MAC}" \
    -p "${SOVIEZ_HOST_PORT}:8069" \
    -e POSTGRES_USER=soviez \
    -e POSTGRES_PASSWORD="${SOVIEZ_DB_PASSWORD}" \
    -e PASSWORD="${SOVIEZ_DB_PASSWORD}" \
    "${volume_args[@]}" \
    "${APP_IMAGE}" \
    python3 soviez-bin -c /opt/soviez-erp/soviez.conf \
      --addons-path="${addons_cli}" \
      --db_host="${DB_CONTAINER}" \
      --db_port=5432 \
      --db_user=soviez \
      --db_password="${SOVIEZ_DB_PASSWORD}" \
      --data-dir=/root/.local/share/Odoo \
      --admin-passwd="${SOVIEZ_ADMIN_PASSWORD}" >/dev/null
}

list_odoo_databases() {
  if [[ -n "${SOVIEZ_DB_NAME:-}" ]]; then
    printf '%s\n' "${SOVIEZ_DB_NAME}"
    return 0
  fi
  docker exec "${DB_CONTAINER}" \
    psql -U soviez -d postgres -Atc \
    "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" \
    2>/dev/null | sed '/^$/d' || true
}

purge_frontend_assets() {
  local dbname="$1"
  docker exec "${DB_CONTAINER}" \
    psql -U soviez -d "${dbname}" -v ON_ERROR_STOP=1 -c \
    "DELETE FROM ir_attachment
     WHERE url LIKE '/web/assets/%'
        OR url LIKE '/web/content/%assets%'
        OR name ILIKE 'web.assets_%'
        OR name ILIKE 'web_enterprise.assets_%'
        OR name ILIKE '%.assets_%.min.js'
        OR name ILIKE '%.assets_%.min.css';" >/dev/null
}

run_schema_upgrades() {
  local dbname
  local dbs
  local count=0
  local upgrade_rc=0
  local addons_cli="/opt/soviez-erp/addons,/opt/soviez-erp/odoo/addons"
  local -a volume_args=(
    -v "${FILESTORE_VOLUME}:/root/.local/share/Odoo/filestore"
    -v "${HOST_SOVIEZ_DIR}:/root/.soviez"
  )

  ensure_host_ledger_dir
  if [[ -n "${CUSTOM_ADDONS_HOST_PATH}" && -d "${CUSTOM_ADDONS_HOST_PATH}" ]]; then
    volume_args+=(-v "${CUSTOM_ADDONS_HOST_PATH}:${CUSTOM_ADDONS_CONTAINER_PATH}")
    addons_cli="${addons_cli},${CUSTOM_ADDONS_CONTAINER_PATH}"
  fi

  mapfile -t dbs < <(list_odoo_databases)
  if ((${#dbs[@]} == 0)); then
    ui_warn "No application databases found — skipping schema upgrade."
    return 0
  fi

  for dbname in "${dbs[@]}"; do
    [[ -z "${dbname}" ]] && continue
    if [[ ! "${dbname}" =~ ^[A-Za-z0-9_:-]+$ ]]; then
      ui_error "Refusing unsafe database name: ${dbname}"
      return 1
    fi
    count=$((count + 1))
    set +e
    docker run --rm \
      --network "${NETWORK_NAME}" \
      --mac-address "${SOVIEZ_CONTAINER_MAC}" \
      -e POSTGRES_USER=soviez \
      -e POSTGRES_PASSWORD="${SOVIEZ_DB_PASSWORD}" \
      "${volume_args[@]}" \
      "${APP_IMAGE}" \
      python3 soviez-bin -c /opt/soviez-erp/soviez.conf \
        --addons-path="${addons_cli}" \
        --db_host="${DB_CONTAINER}" \
        --db_port=5432 \
        --db_user=soviez \
        --db_password="${SOVIEZ_DB_PASSWORD}" \
        --data-dir=/root/.local/share/Odoo \
        --admin-passwd="${SOVIEZ_ADMIN_PASSWORD}" \
        -d "${dbname}" \
        -u "${UPGRADE_MODULES}" \
        --stop-after-init >>"${LOG_FILE}" 2>&1
    upgrade_rc=$?
    set -e
    if (( upgrade_rc != 0 )); then
      ui_error "Schema upgrade failed for '${dbname}' (exit ${upgrade_rc})."
      return "${upgrade_rc}"
    fi
    purge_frontend_assets "${dbname}" || return 1
  done
  log_file "Upgraded ${count} database(s)"
}

require_complete_env() {
  if [[ -z "${SOVIEZ_CONTAINER_MAC:-}" || -z "${SOVIEZ_DB_PASSWORD:-}" || -z "${SOVIEZ_HOST_PORT:-}" || -z "${SOVIEZ_ADMIN_PASSWORD:-}" ]]; then
    ui_error "${ENV_FILE} is missing required secrets (MAC / DB password / admin password / host port)."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Public IP / DNS / Nginx / Certbot / UFW  (--init / --new)
# ---------------------------------------------------------------------------
detect_public_ip() {
  local ip=""
  if command -v curl >/dev/null 2>&1; then
    ip="$(curl -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  fi
  if [[ -z "${ip}" ]]; then
    ip="$(python3 - <<'PY' 2>/dev/null || true
import urllib.request
print(urllib.request.urlopen("https://api.ipify.org", timeout=8).read().decode().strip())
PY
)"
  fi
  if [[ -z "${ip}" ]]; then
    ui_error "Could not detect public IP (api.ipify.org unreachable)."
    exit 1
  fi
  printf '%s\n' "${ip}"
}

resolve_domain_ips() {
  local domain="$1"
  python3 - "${domain}" <<'PY'
import socket
import sys
domain = sys.argv[1]
try:
    infos = socket.getaddrinfo(domain, None)
except Exception:
    sys.exit(2)
ips = sorted({i[4][0] for i in infos if i[4] and i[4][0]})
print("\n".join(ips))
PY
}

normalize_domain() {
  local d="$1"
  d="${d,,}"
  d="${d#http://}"
  d="${d#https://}"
  d="${d%%/*}"
  d="${d%%:*}"
  printf '%s\n' "${d}"
}

prompt_domain_confirmed() {
  local d1 d2
  while true; do
    echo ""
    read -r -p "🌐  Enter your domain or subdomain: " d1
    d1="$(normalize_domain "${d1}")"
    if [[ -z "${d1}" || ! "${d1}" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
      ui_warn "Invalid domain. Example: erp.example.com"
      continue
    fi
    read -r -p "🔁  Confirm domain (type again): " d2
    d2="$(normalize_domain "${d2}")"
    if [[ "${d1}" != "${d2}" ]]; then
      ui_warn "Domains did not match. Try again."
      continue
    fi
    TENANT_DOMAIN="${d1}"
    return 0
  done
}

dns_validation_loop() {
  local public_ip="$1"
  local domain="$2"
  local resolved
  local answer

  while true; do
    ui_wait "Checking DNS for ${domain} → ${public_ip}..."
    set +e
    resolved="$(resolve_domain_ips "${domain}" 2>/dev/null)"
    local rc=$?
    set -e

    if (( rc == 0 )) && printf '%s\n' "${resolved}" | grep -Fxq "${public_ip}"; then
      ui_ok "DNS matched — ${domain} resolves to ${public_ip}"
      return 0
    fi

    echo ""
    ui_warn "Domain is not pointed to this IP yet. DNS propagation can take up to 48 hours."
    if [[ -n "${resolved}" ]]; then
      echo -e "  ${C_DIM}Currently resolves to:${C_RESET} ${resolved//$'\n'/, }"
    else
      echo -e "  ${C_DIM}Currently resolves to:${C_RESET} (none / NXDOMAIN)"
    fi
    echo -e "  ${C_DIM}Expected Public IP:${C_RESET} ${public_ip}"
    echo ""
    read -r -p "Retry DNS check now? (y/n) — or type 'force' to override: " answer
    answer="${answer,,}"
    case "${answer}" in
      y|yes) continue ;;
      force)
        ui_warn "Operator force-override accepted — continuing without verified DNS."
        return 0
        ;;
      *)
        ui_error "DNS not verified. Exiting. Re-run ./setup.sh --new when ready."
        exit 1
        ;;
    esac
  done
}

# Ensure http-context map + ERP proxy limits exist. Prevents:
#   nginx: [emerg] unknown "connection_upgrade" variable
# Safe to call even when --init was skipped or interrupted.
ensure_nginx_global_limits() {
  local needs_write=0

  mkdir -p /etc/nginx/conf.d

  if [[ ! -f "${NGINX_LIMITS_CONF}" ]]; then
    needs_write=1
    log_file "Nginx limits file missing — will write ${NGINX_LIMITS_CONF}"
  elif ! grep -Eq 'map[[:space:]]+\$http_upgrade[[:space:]]+\$connection_upgrade' "${NGINX_LIMITS_CONF}"; then
    needs_write=1
    log_file "Nginx limits file lacks connection_upgrade map — rewriting ${NGINX_LIMITS_CONF}"
  fi

  if (( needs_write == 1 )); then
    ui_wait "Writing Nginx global limits (connection_upgrade map)..."
    cat > "${NGINX_LIMITS_CONF}" <<'EOF'
# Soviez ERP — global proxy limits for heavy ERP/Odoo traffic
client_max_body_size 512M;
proxy_read_timeout 720s;
proxy_connect_timeout 720s;
proxy_send_timeout 720s;

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
EOF
    ui_ok "Nginx global limits written (${NGINX_LIMITS_CONF})"
  else
    log_file "Nginx global limits already present with connection_upgrade map"
  fi
}

# Back-compat alias used by --init progress helper.
configure_nginx_global_limits() {
  ensure_nginx_global_limits
  if ! nginx -t >>"${LOG_FILE}" 2>&1; then
    ui_error "Nginx configuration test failed after writing ${NGINX_LIMITS_CONF}"
    return 1
  fi
  systemctl reload nginx >>"${LOG_FILE}" 2>&1 || systemctl start nginx >>"${LOG_FILE}" 2>&1 || true
}

write_nginx_site() {
  local domain="$1"
  local host_port="$2"
  local site_file="/etc/nginx/sites-available/soviez-${domain}.conf"
  local enabled_link="/etc/nginx/sites-enabled/soviez-${domain}.conf"

  # Defensive: never nginx -t a site that references $connection_upgrade without the map.
  ensure_nginx_global_limits

  cat > "${site_file}" <<EOF
# Soviez ERP tenant — ${domain} → 127.0.0.1:${host_port}
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    client_max_body_size 512M;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    location / {
        proxy_pass http://127.0.0.1:${host_port};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_redirect off;
    }

    location /websocket {
        proxy_pass http://127.0.0.1:${host_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 720s;
    }
}
EOF

  ln -sfn "${site_file}" "${enabled_link}"
  # Disable default site when present (idempotent)
  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

  if ! nginx -t >>"${LOG_FILE}" 2>&1; then
    ui_error "Nginx site config failed for ${domain} — see ${LOG_FILE}"
    return 1
  fi
  systemctl reload nginx >>"${LOG_FILE}" 2>&1
}

install_docker_engine() {
  if command -v docker >/dev/null 2>&1; then
    local ver major
    ver="$(docker version --format '{{.Server.Version}}' 2>/dev/null || docker --version | awk '{print $3}' | tr -d ',')"
    major="${ver%%.*}"
    if [[ "${major}" =~ ^[0-9]+$ ]] && (( major >= 20 )); then
      ui_ok "Docker ${ver} already installed"
      systemctl enable --now docker >>"${LOG_FILE}" 2>&1 || true
      return 0
    fi
    ui_warn "Docker ${ver} is outdated — upgrading via official convenience script..."
  else
    ui_wait "Docker not found — installing via official convenience script..."
  fi

  show_progress "Installing Docker Engine..." bash -c \
    'curl -fsSL https://get.docker.com | sh' || {
      ui_error "Docker installation failed — see ${LOG_FILE}"
      exit 1
    }
  systemctl enable --now docker >>"${LOG_FILE}" 2>&1
  ui_ok "Docker Engine ready"
}

ensure_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    show_progress "Installing UFW..." apt-get install -y ufw || return 1
  fi
  # Open required ports BEFORE enabling (preserve SSH)
  ufw allow 22/tcp >>"${LOG_FILE}" 2>&1 || true
  ufw allow OpenSSH >>"${LOG_FILE}" 2>&1 || true
  ufw allow 80/tcp >>"${LOG_FILE}" 2>&1 || true
  ufw allow 443/tcp >>"${LOG_FILE}" 2>&1 || true
  ufw --force enable >>"${LOG_FILE}" 2>&1 || true
  ui_ok "UFW active — ports 22 / 80 / 443 allowed"
}

print_elite_welcome() {
  local domain="$1"
  local addons_path="$2"
  local admin_password="$3"
  local index="$4"

  clear 2>/dev/null || true
  echo ""
  echo -e "${C_GREEN}${C_BOLD}"
  cat <<'BANNER'
   ███████╗ ██████╗ ██╗   ██╗██╗███████╗███████╗
   ██╔════╝██╔═══██╗██║   ██║██║██╔════╝╚══███╔╝
   ███████╗██║   ██║██║   ██║██║█████╗    ███╔╝
   ╚════██║██║   ██║╚██╗ ██╔╝██║██╔══╝   ███╔╝
   ███████║╚██████╔╝ ╚████╔╝ ██║███████╗███████╗
   ╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚══════╝╚══════╝
            E R P   E C O S Y S T E M
BANNER
  echo -e "${C_RESET}"
  echo -e "  ${C_GREEN}✔${C_RESET}  ${C_BOLD}Welcome to the Soviez ERP ecosystem!${C_RESET}"
  echo -e "  ${C_GREEN}✔${C_RESET}  Tenant instance #${index} is live and secured."
  echo ""
  echo -e "  ${C_BOLD}Live URL${C_RESET}"
  echo -e "     ${C_CYAN}https://${domain}${C_RESET}"
  echo ""
  echo -e "  ${C_BOLD}Custom addons folder${C_RESET}"
  echo -e "     ${C_CYAN}${addons_path}${C_RESET}"
  echo -e "     ${C_DIM}Drop Odoo modules here, then refresh Apps or run ./setup.sh --update${C_RESET}"
  echo ""
  print_master_password_alert \
    "${admin_password}" \
    "INSTANCE #${index} — DATABASE MASTER PASSWORD (SAVE THIS NOW)"
  echo -e "  ${C_DIM}Full setup log: ${LOG_FILE}${C_RESET}"
  echo ""
}

# ===========================================================================
# MODE: init — host environment only
# ===========================================================================
mode_init() {
  require_root --init
  ensure_log_file
  export DEBIAN_FRONTEND=noninteractive

  print_border_box "Soviez ERP — Host Initialization" \
    "Preparing a production-ready Ubuntu/Debian appliance." \
    "Containers are NOT launched in this mode." \
    "After success, provision tenants with: ./setup.sh --new"

  show_progress "Updating system components..." bash -c \
    'apt-get update -y && apt-get upgrade -y' || {
      ui_error "System update failed — see ${LOG_FILE}"
      exit 1
    }

  show_progress "Installing base utilities (curl, ca-certificates)..." \
    apt-get install -y curl ca-certificates gnupg lsb-release || true

  install_docker_engine

  if ! command -v nginx >/dev/null 2>&1; then
    show_progress "Installing Nginx..." apt-get install -y nginx || exit 1
  else
    ui_ok "Nginx already installed"
  fi
  systemctl enable --now nginx >>"${LOG_FILE}" 2>&1 || true
  show_progress "Applying Nginx ERP traffic limits..." configure_nginx_global_limits

  show_progress "Installing Certbot (nginx plugin)..." \
    apt-get install -y certbot python3-certbot-nginx || exit 1

  ensure_ufw

  print_green_success "Host environment successfully initialized!"
  echo -e "  You can now provision instances using:"
  echo -e "    ${C_BOLD}sudo ./setup.sh --new${C_RESET}"
  echo -e "  Log file: ${C_DIM}${LOG_FILE}${C_RESET}"
  echo ""
}

# ===========================================================================
# MODE: new — tenant provisioning
# ===========================================================================
mode_new() {
  require_root --new
  ensure_log_file
  require_cmd docker
  require_cmd python3
  ensure_host_ledger_dir

  if ! command -v nginx >/dev/null 2>&1 || ! command -v certbot >/dev/null 2>&1; then
    ui_error "Host not initialized. Run first: sudo ./setup.sh --init"
    exit 1
  fi

  local public_ip next_index
  public_ip="$(detect_public_ip)"

  print_border_box "Welcome to Soviez ERP Tenant Provisioning" \
    "To proceed, you need a domain or subdomain pointed to this server's" \
    "Public IP: ${C_BOLD}${public_ip}${C_RESET}" \
    "" \
    "This wizard will create an isolated container stack + HTTPS site."

  prompt_domain_confirmed
  dns_validation_loop "${public_ip}" "${TENANT_DOMAIN}"

  mkdir -p "${INSTANCE_ROOT}"
  next_index="$(find_next_instance_index)"
  apply_topology_indexed "${next_index}"

  if [[ -f "${ENV_FILE}" ]]; then
    ui_error "Target environment already exists: ${ENV_FILE}"
    exit 1
  fi

  ui_info "Provisioning isolated tenant index=${next_index} (${WEB_CONTAINER})"
  ensure_custom_addons_dir

  SOVIEZ_CONTAINER_MAC="$(generate_mac)"
  SOVIEZ_DB_PASSWORD="$(generate_password)"
  SOVIEZ_ADMIN_PASSWORD="$(generate_password)"
  SOVIEZ_HOST_PORT="$(find_free_host_port "${MULTI_PORT_START}")"

  cat > "${ENV_FILE}" <<EOF
SOVIEZ_INSTANCE_INDEX=${next_index}
SOVIEZ_HOST_PORT=${SOVIEZ_HOST_PORT}
SOVIEZ_CONTAINER_MAC=${SOVIEZ_CONTAINER_MAC}
SOVIEZ_DB_PASSWORD=${SOVIEZ_DB_PASSWORD}
SOVIEZ_ADMIN_PASSWORD=${SOVIEZ_ADMIN_PASSWORD}
SOVIEZ_NETWORK_NAME=${NETWORK_NAME}
SOVIEZ_DB_CONTAINER=${DB_CONTAINER}
SOVIEZ_WEB_CONTAINER=${WEB_CONTAINER}
SOVIEZ_DB_VOLUME=${DB_VOLUME}
SOVIEZ_FILESTORE_VOLUME=${FILESTORE_VOLUME}
SOVIEZ_CUSTOM_ADDONS_HOST=${CUSTOM_ADDONS_HOST_PATH}
SOVIEZ_CUSTOM_ADDONS_MOUNT=${CUSTOM_ADDONS_CONTAINER_PATH}
SOVIEZ_TENANT_DOMAIN=${TENANT_DOMAIN}
SOVIEZ_PUBLIC_IP=${public_ip}
EOF
  chmod 600 "${ENV_FILE}"

  show_progress "Pulling container images..." bash -c \
    "docker pull '${APP_IMAGE}' && docker pull '${DB_IMAGE}'"

  show_progress "Creating network and volumes..." ensure_network_and_volumes
  show_progress "Starting PostgreSQL (${DB_CONTAINER})..." ensure_postgres_container

  if container_exists "${WEB_CONTAINER}"; then
    docker rm -f "${WEB_CONTAINER}" >/dev/null 2>&1 || true
  fi
  show_progress "Launching Soviez ERP (${WEB_CONTAINER})..." launch_web_container

  show_progress "Writing Nginx site for ${TENANT_DOMAIN}..." \
    write_nginx_site "${TENANT_DOMAIN}" "${SOVIEZ_HOST_PORT}"

  show_progress "Provisioning Let's Encrypt SSL for ${TENANT_DOMAIN}..." bash -c \
    "certbot --nginx -d '${TENANT_DOMAIN}' --non-interactive --agree-tos --register-unsafely-without-email --redirect" \
    || ui_warn "Certbot did not complete — HTTP site is live; re-run certbot when DNS is ready."

  print_elite_welcome \
    "${TENANT_DOMAIN}" \
    "${CUSTOM_ADDONS_HOST_PATH}" \
    "${SOVIEZ_ADMIN_PASSWORD}" \
    "${next_index}"
}

# ===========================================================================
# MODE: formsetup — idempotent resume / heal of latest half-configured tenant
# ===========================================================================
mode_formsetup() {
  require_root --formsetup
  ensure_log_file
  require_cmd docker
  require_cmd python3
  ensure_host_ledger_dir

  if ! command -v nginx >/dev/null 2>&1 || ! command -v certbot >/dev/null 2>&1; then
    ui_error "Host not initialized. Run first: sudo ./setup.sh --init"
    exit 1
  fi

  local target_index
  target_index="$(select_formsetup_index)"
  if (( target_index < 1 )); then
    ui_error "No tenant environment sheet found. Provision with: sudo ./setup.sh --new"
    exit 1
  fi

  apply_topology_indexed "${target_index}"
  if [[ ! -f "${ENV_FILE}" ]]; then
    ui_error "Missing environment sheet for index ${target_index}: ${ENV_FILE}"
    exit 1
  fi

  load_env_file
  require_complete_env

  NETWORK_NAME="${SOVIEZ_NETWORK_NAME:-${NETWORK_NAME}}"
  DB_CONTAINER="${SOVIEZ_DB_CONTAINER:-${DB_CONTAINER}}"
  WEB_CONTAINER="${SOVIEZ_WEB_CONTAINER:-${WEB_CONTAINER}}"
  DB_VOLUME="${SOVIEZ_DB_VOLUME:-${DB_VOLUME}}"
  FILESTORE_VOLUME="${SOVIEZ_FILESTORE_VOLUME:-${FILESTORE_VOLUME}}"
  INSTANCE_INDEX="${SOVIEZ_INSTANCE_INDEX:-${target_index}}"
  CUSTOM_ADDONS_HOST_PATH="${SOVIEZ_CUSTOM_ADDONS_HOST:-${CUSTOM_ADDONS_HOST_PATH}}"
  if [[ -z "${CUSTOM_ADDONS_HOST_PATH}" ]]; then
    CUSTOM_ADDONS_HOST_PATH="/etc/soviez_web_${INSTANCE_INDEX}/addons"
  fi
  TENANT_DOMAIN="${SOVIEZ_TENANT_DOMAIN:-}"

  if [[ -z "${TENANT_DOMAIN}" ]]; then
    ui_error "${ENV_FILE} has no SOVIEZ_TENANT_DOMAIN — cannot resume Nginx/SSL."
    exit 1
  fi

  print_border_box "Soviez ERP — Form Setup Recovery" \
    "Resuming tenant index ${C_BOLD}#${INSTANCE_INDEX}${C_RESET} (${WEB_CONTAINER})" \
    "Domain: ${C_BOLD}${TENANT_DOMAIN}${C_RESET}" \
    "Env: ${ENV_FILE}" \
    "" \
    "Pipeline is idempotent: existing assets are kept; Nginx/SSL are rebuilt."

  ui_info "Healing half-configured instance index=${INSTANCE_INDEX}"
  ensure_custom_addons_dir

  resume_network_and_volumes
  resume_postgres_container
  resume_web_container

  ui_wait "Regenerating Nginx vhost + global limits for ${TENANT_DOMAIN}..."
  if ! write_nginx_site "${TENANT_DOMAIN}" "${SOVIEZ_HOST_PORT}"; then
    ui_error "Nginx recovery failed — see ${LOG_FILE}"
    exit 1
  fi
  ui_ok "Nginx site ready for ${TENANT_DOMAIN}"

  show_progress "Provisioning Let's Encrypt SSL for ${TENANT_DOMAIN}..." bash -c \
    "certbot --nginx -d '${TENANT_DOMAIN}' --non-interactive --agree-tos --register-unsafely-without-email --redirect" \
    || ui_warn "Certbot did not complete — HTTP site is live; re-run ./setup.sh --formsetup when DNS is ready."

  print_elite_welcome \
    "${TENANT_DOMAIN}" \
    "${CUSTOM_ADDONS_HOST_PATH}" \
    "${SOVIEZ_ADMIN_PASSWORD}" \
    "${INSTANCE_INDEX}"
}

# ===========================================================================
# MODE: update — pull image + recycle web runners (all envs)
# ===========================================================================
mode_update() {
  ensure_log_file
  require_cmd docker
  require_cmd python3
  ensure_host_ledger_dir

  local env_path
  local -a env_files=()

  # Indexed tenants
  shopt -s nullglob
  for env_path in "${INSTANCE_ROOT}"/.soviez_*.env "$(pwd)"/.soviez_*.env; do
    [[ -f "${env_path}" ]] || continue
    env_files+=("${env_path}")
  done
  shopt -u nullglob

  # Legacy primary (optional)
  for env_path in "${INSTANCE_ROOT}/.soviez.env" "$(pwd)/.soviez.env"; do
    if [[ -f "${env_path}" ]]; then
      env_files+=("${env_path}")
    fi
  done

  if ((${#env_files[@]} == 0)); then
    ui_error "No Soviez environments found. Provision one with: sudo ./setup.sh --new"
    exit 1
  fi

  show_progress "Pulling ${APP_IMAGE}..." docker pull "${APP_IMAGE}"

  local processed=()
  for env_path in "${env_files[@]}"; do
    # Deduplicate by realpath when both INSTANCE_ROOT and cwd point at same file
    local real
    real="$(readlink -f "${env_path}" 2>/dev/null || echo "${env_path}")"
    local skip=0
    local prev
    for prev in "${processed[@]:-}"; do
      if [[ "${prev}" == "${real}" ]]; then
        skip=1
        break
      fi
    done
    (( skip == 1 )) && continue
    processed+=("${real}")

    ENV_FILE="${env_path}"
    ui_info "Updating instance from ${ENV_FILE}"
    load_env_file
    require_complete_env

    NETWORK_NAME="${SOVIEZ_NETWORK_NAME:-${NETWORK_NAME}}"
    DB_CONTAINER="${SOVIEZ_DB_CONTAINER:-${DB_CONTAINER}}"
    WEB_CONTAINER="${SOVIEZ_WEB_CONTAINER:-${WEB_CONTAINER}}"
    DB_VOLUME="${SOVIEZ_DB_VOLUME:-${DB_VOLUME}}"
    FILESTORE_VOLUME="${SOVIEZ_FILESTORE_VOLUME:-${FILESTORE_VOLUME}}"
    INSTANCE_INDEX="${SOVIEZ_INSTANCE_INDEX:-}"
    CUSTOM_ADDONS_HOST_PATH="${SOVIEZ_CUSTOM_ADDONS_HOST:-}"
    if [[ -z "${CUSTOM_ADDONS_HOST_PATH}" && -n "${INSTANCE_INDEX}" ]]; then
      CUSTOM_ADDONS_HOST_PATH="/etc/soviez_web_${INSTANCE_INDEX}/addons"
    fi

    if ! container_running "${DB_CONTAINER}"; then
      if container_exists "${DB_CONTAINER}"; then
        docker start "${DB_CONTAINER}" >/dev/null
      else
        ui_error "Database container '${DB_CONTAINER}' missing — skip ${ENV_FILE}"
        continue
      fi
    fi
    wait_for_postgres || continue

    ui_wait "Stopping web runner ${WEB_CONTAINER}..."
    docker stop "${WEB_CONTAINER}" >>"${LOG_FILE}" 2>&1 || true
    docker rm -f "${WEB_CONTAINER}" >>"${LOG_FILE}" 2>&1 || true

    if ! show_progress "Schema upgrade (${WEB_CONTAINER})..." run_schema_upgrades; then
      ui_error "Upgrade aborted for ${WEB_CONTAINER} — left offline. Fix and re-run --update."
      continue
    fi

    show_progress "Relaunching ${WEB_CONTAINER}..." launch_web_container
    ui_ok "Recycled ${WEB_CONTAINER} on ${APP_IMAGE}"
  done

  print_green_success "Update complete — web runners recycled on ${APP_IMAGE}"
  echo -e "  Log: ${C_DIM}${LOG_FILE}${C_RESET}"
  echo ""
}

# ===========================================================================
# MODE: recover — rotate admin password + recycle one web runner
# ===========================================================================
mode_recover() {
  ensure_log_file
  require_cmd docker
  require_cmd python3

  apply_topology_primary
  if [[ ! -f "${ENV_FILE}" ]]; then
    # Fall back to highest indexed tenant if no primary
    local idx
    idx="$(find_next_instance_index)"
    if (( idx > 1 )); then
      apply_topology_indexed $((idx - 1))
    fi
  fi

  if [[ ! -f "${ENV_FILE}" ]]; then
    ui_error "No Soviez installation found to recover."
    exit 1
  fi

  load_env_file
  NETWORK_NAME="${SOVIEZ_NETWORK_NAME:-${NETWORK_NAME}}"
  DB_CONTAINER="${SOVIEZ_DB_CONTAINER:-${DB_CONTAINER}}"
  WEB_CONTAINER="${SOVIEZ_WEB_CONTAINER:-${WEB_CONTAINER}}"
  DB_VOLUME="${SOVIEZ_DB_VOLUME:-${DB_VOLUME}}"
  FILESTORE_VOLUME="${SOVIEZ_FILESTORE_VOLUME:-${FILESTORE_VOLUME}}"
  INSTANCE_INDEX="${SOVIEZ_INSTANCE_INDEX:-}"
  CUSTOM_ADDONS_HOST_PATH="${SOVIEZ_CUSTOM_ADDONS_HOST:-}"

  if [[ -z "${SOVIEZ_CONTAINER_MAC:-}" || -z "${SOVIEZ_DB_PASSWORD:-}" || -z "${SOVIEZ_HOST_PORT:-}" ]]; then
    ui_error "${ENV_FILE} is incomplete — cannot recover master password."
    exit 1
  fi

  ui_info "Rotating Database Master Password..."
  SOVIEZ_ADMIN_PASSWORD="$(generate_password)"
  persist_env_key "SOVIEZ_ADMIN_PASSWORD" "${SOVIEZ_ADMIN_PASSWORD}"
  load_env_file

  ensure_network_and_volumes
  docker rm -f "${WEB_CONTAINER}" 2>/dev/null || true
  show_progress "Pulling ${APP_IMAGE}..." docker pull "${APP_IMAGE}"
  show_progress "Recycling ${WEB_CONTAINER}..." launch_web_container

  print_master_password_alert \
    "${SOVIEZ_ADMIN_PASSWORD}" \
    "MASTER PASSWORD RESET — APPLICATION LAYER RECYCLED"
  ui_ok "Master Password reset. Volumes preserved."
}

# ===========================================================================
# Dispatch
# ===========================================================================
ensure_log_file

case "${MODE}" in
  init)
    mode_init
    ;;
  new)
    mode_new
    ;;
  formsetup)
    mode_formsetup
    ;;
  update)
    mode_update
    ;;
  recover)
    mode_recover
    ;;
  *)
    ui_error "Unknown mode: ${MODE}"
    exit 1
    ;;
esac
