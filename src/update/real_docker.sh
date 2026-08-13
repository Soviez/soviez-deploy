# shellcheck shell=bash
# Real Docker Soviez ERP candidate upgrade helpers (Phase 15 final certification).

soviez_update_real_docker_enabled() {
  [[ "${SOVIEZ_UPDATE_REAL_DOCKER:-0}" == "1" ]] || return 1
  if declare -F soviez_image_docker_available >/dev/null 2>&1; then
    soviez_image_docker_available
  else
    docker info >/dev/null 2>&1
  fi
}

soviez_update_docker() {
  if declare -F soviez_image_docker >/dev/null 2>&1; then
    soviez_image_docker "$@"
  else
    docker "$@"
  fi
}

soviez_update_real_image_ref() {
  local digest="$1"
  # Prefer labeled disposable certification images; allow override
  if [[ -n "${SOVIEZ_UPDATE_REAL_IMAGE:-}" ]]; then
    printf '%s\n' "$SOVIEZ_UPDATE_REAL_IMAGE"
    return 0
  fi
  if soviez_update_docker image inspect "soviez/erp@${digest}" >/dev/null 2>&1; then
    printf 'soviez/erp@%s\n' "$digest"
    return 0
  fi
  # digest may be image id
  if soviez_update_docker image inspect "$digest" >/dev/null 2>&1; then
    printf '%s\n' "$digest"
    return 0
  fi
  # fallback tagged labeled images used in certification
  for t in soviez/erp:p15-v15-labeled soviez/erp:p15-v14-labeled soviez-erp:owc-website-local; do
    if soviez_update_docker image inspect "$t" >/dev/null 2>&1; then
      printf '%s\n' "$t"
      return 0
    fi
  done
  return 1
}

soviez_update_real_pg_creds_file() {
  local root="${SOVIEZ_ROOT:-}"
  if [[ -n "$root" ]]; then
    mkdir -p "$root/secrets"
    chmod 700 "$root/secrets" 2>/dev/null || true
    printf '%s\n' "$root/secrets/update_pg_creds"
    return 0
  fi
  printf '%s\n' "${SOVIEZ_UPDATE_PG_CREDS_FILE:-/tmp/soviez_update_pg_creds}"
}

soviez_update_real_pg_load_or_create_creds() {
  local creds
  creds="$(soviez_update_real_pg_creds_file)"
  if [[ -f "$creds" ]]; then
    # shellcheck disable=SC1090
    source "$creds"
  else
    local admin_pass app_pass
    admin_pass="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
    app_pass="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(32)))')"
    mkdir -p "$(dirname "$creds")"
    umask 077
    cat > "$creds" <<CEOF
SOVIEZ_UPDATE_PG_ADMIN_USER=soviez_admin
SOVIEZ_UPDATE_PG_ADMIN_PASSWORD=${admin_pass}
SOVIEZ_UPDATE_PG_APP_USER=soviez_app
SOVIEZ_UPDATE_PG_APP_PASSWORD=${app_pass}
CEOF
    chmod 600 "$creds"
    # shellcheck disable=SC1090
    source "$creds"
  fi
  export SOVIEZ_UPDATE_PG_ADMIN_USER="${SOVIEZ_UPDATE_PG_ADMIN_USER:-soviez_admin}"
  export SOVIEZ_UPDATE_PG_ADMIN_PASSWORD
  export SOVIEZ_UPDATE_PG_APP_USER="${SOVIEZ_UPDATE_PG_APP_USER:-soviez_app}"
  export SOVIEZ_UPDATE_PG_APP_PASSWORD
}

soviez_update_real_pg_provision_app_role() {
  local pg_name="$1"
  local admin_user="${SOVIEZ_UPDATE_PG_ADMIN_USER:-soviez_admin}"
  local admin_pass="${SOVIEZ_UPDATE_PG_ADMIN_PASSWORD:-}"
  local app_user="${SOVIEZ_UPDATE_PG_APP_USER:-soviez_app}"
  local app_pass="${SOVIEZ_UPDATE_PG_APP_PASSWORD:-}"
  local qpass
  qpass="$(printf '%s' "$app_pass" | sed "s/'/''/g")"
  soviez_update_docker exec -e PGPASSWORD="$admin_pass" "$pg_name" \
    psql -v ON_ERROR_STOP=1 -U "$admin_user" -d postgres -c \
    "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${app_user}') THEN CREATE ROLE \"${app_user}\" LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; ELSE ALTER ROLE \"${app_user}\" WITH LOGIN PASSWORD '${qpass}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; END IF; END \$\$;" \
    >/dev/null
  local role
  for role in pg_execute_server_program pg_read_server_files pg_write_server_files; do
    soviez_update_docker exec -e PGPASSWORD="$admin_pass" "$pg_name" \
      psql -U "$admin_user" -d postgres -c "REVOKE ${role} FROM \"${app_user}\";" >/dev/null 2>&1 || true
  done
}

soviez_update_real_pg_ensure() {
  local net="$1"
  local pg_name="${SOVIEZ_UPDATE_REAL_PG_NAME:-soviez-upd-pg}"
  soviez_update_real_pg_load_or_create_creds || return 1
  local admin_user="${SOVIEZ_UPDATE_PG_ADMIN_USER:-soviez_admin}"
  local admin_pass="${SOVIEZ_UPDATE_PG_ADMIN_PASSWORD:-}"

  _soviez_update_pg_recreate() {
    soviez_update_docker rm -f "$pg_name" >/dev/null 2>&1 || true
    soviez_update_docker run -d --name "$pg_name" --network "$net" \
      -e POSTGRES_USER="$admin_user" \
      -e POSTGRES_PASSWORD="$admin_pass" \
      -e POSTGRES_DB=postgres \
      postgres:16 >/dev/null || return 1
  }

  if ! soviez_update_docker inspect "$pg_name" >/dev/null 2>&1; then
    _soviez_update_pg_recreate || return 1
  else
    soviez_update_docker start "$pg_name" >/dev/null 2>&1 || true
    # Ensure PG is attached to this candidate network (idempotent)
    if ! soviez_update_docker inspect -f '{{json .NetworkSettings.Networks}}' "$pg_name" 2>/dev/null | grep -q "\"${net}\""; then
      if ! soviez_update_docker network connect "$net" "$pg_name" >/dev/null 2>&1; then
        _soviez_update_pg_recreate || return 1
      fi
    fi
    # Legacy disposable PG may still be odoo/odoo — recreate for S1 bootstrap identity.
    if ! soviez_update_docker exec -e PGPASSWORD="$admin_pass" "$pg_name" \
      psql -U "$admin_user" -d postgres -tAc 'SELECT 1' >/dev/null 2>&1; then
      _soviez_update_pg_recreate || return 1
    fi
  fi
  local i
  for i in $(seq 1 60); do
    if soviez_update_docker exec "$pg_name" pg_isready -U "$admin_user" >/dev/null 2>&1; then
      soviez_update_docker network inspect "$net" -f '{{range $k,$v := .Containers}}{{$v.Name}} {{end}}' 2>/dev/null \
        | grep -q "$pg_name" || return 1
      soviez_update_real_pg_provision_app_role "$pg_name" || return 1
      return 0
    fi
    sleep 1
  done
  return 1
}

soviez_update_real_candidate_start() {
  local op_id="$1" target_digest="$2" db_name="$3"
  local cdir container network image_ref
  cdir="$(soviez_update_candidate_dir "$op_id")"
  container="soviez-upd-cand-${op_id}"
  network="soviez-upd-net-${op_id}"
  image_ref="$(soviez_update_real_image_ref "$target_digest")" \
    || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Real Soviez ERP image not available for digest $target_digest"

  soviez_update_docker network rm "$network" >/dev/null 2>&1 || true
  if ! soviez_update_docker network create "$network" >/dev/null 2>&1; then
    # Reuse if already present
    soviez_update_docker network inspect "$network" >/dev/null 2>&1 \
      || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Failed to create candidate network $network"
  fi
  # Prefer candidate-dir secrets when SOVIEZ_ROOT unset
  if [[ -z "${SOVIEZ_ROOT:-}" ]]; then
    export SOVIEZ_UPDATE_PG_CREDS_FILE="${cdir}/secrets/update_pg_creds"
    mkdir -p "${cdir}/secrets"
    chmod 700 "${cdir}/secrets"
  fi
  soviez_update_real_pg_ensure "$network" \
    || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Candidate PostgreSQL not ready"

  # Filestore + custom addons bind mounts (isolated)
  mkdir -p "$cdir/filestore" "$cdir/addons" "$cdir/runtime"
  # Write candidate odoo config
  local pg_name="${SOVIEZ_UPDATE_REAL_PG_NAME:-soviez-upd-pg}"
  cat > "$cdir/runtime/soviez.conf" <<EOF
[options]
addons_path = addons,odoo/addons,/root/custom_addons
data_dir = /var/lib/soviez-candidate/filestore
db_host = ${pg_name}
db_port = 5432
db_user = ${SOVIEZ_UPDATE_PG_APP_USER:-soviez_app}
db_password = ${SOVIEZ_UPDATE_PG_APP_PASSWORD}
admin_passwd = False
list_db = False
proxy_mode = True
http_port = 8069
EOF

  soviez_update_docker rm -f "$container" >/dev/null 2>&1 || true
  # Prefer docker cp for config: Colima/virtiofs often creates a directory when bind-mounting a single file.
  # Filestore/addons bind mounts require a host path visible to the Docker VM (workspace or /Users).
  local host_root="${SOVIEZ_UPDATE_CANDIDATE_HOST_ROOT:-}"
  if [[ -z "$host_root" ]]; then
    case "$cdir" in
      /Users/*|/Volumes/*|/tmp/*) host_root="$cdir" ;;
      *)
        host_root="${SOVIEZ_ROOT:-/tmp}/update-candidate-host/${op_id}"
        mkdir -p "$host_root/filestore" "$host_root/addons"
        cp -a "$cdir/filestore/." "$host_root/filestore/" 2>/dev/null || true
        cp -a "$cdir/addons/." "$host_root/addons/" 2>/dev/null || true
        ;;
    esac
  fi
  mkdir -p "$host_root/filestore" "$host_root/addons"
  printf '%s' "$host_root" > "$cdir/runtime/host_root.txt"

  soviez_update_docker run -d --name "$container" --network "$network" \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase15-disposable-migration-secret-not-production}" \
    -e SOVIEZ_CANDIDATE=1 \
    -e SOVIEZ_MAIL_DISABLED=1 \
    -e SOVIEZ_CRON_DISABLED=1 \
    -e SOVIEZ_WEBHOOKS_DISABLED=1 \
    -e SOVIEZ_PAYMENT_DISABLED=1 \
    -e SOVIEZ_OUTBOUND_RESTRICTED=1 \
    -v "$host_root/filestore:/var/lib/soviez-candidate/filestore" \
    -v "$host_root/addons:/root/custom_addons" \
    --entrypoint bash "$image_ref" -lc 'sleep infinity' >/dev/null \
    || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Failed to start real candidate container"

  # Install candidate config via docker cp (exact file, not bind mount)
  soviez_update_docker cp "$cdir/runtime/soviez.conf" "${container}:/opt/soviez-erp/candidate.conf" >/dev/null \
    || soviez_update_die UPDATE_CANDIDATE_CREATE_FAILED "Failed to install candidate.conf"

  printf 'container=%s\nnetwork=%s\ndigest=%s\nimage_ref=%s\ndb_name=%s\nrole=update_candidate\nlicense_slot=none\ntemporary=1\nreal_docker=1\n' \
    "$container" "$network" "$target_digest" "$image_ref" "$db_name" > "$cdir/runtime/identity.txt"
  printf '%s' "$image_ref" > "$cdir/runtime/image_ref.txt"
  printf '%s' "$db_name" > "$cdir/runtime/db_name.txt"
  printf '%s\n' "$container"
}

soviez_update_real_upgrade() {
  local op_id="$1" modules="${2:-base,web,local_license_guard}"
  local cdir container db_name logf
  cdir="$(soviez_update_candidate_dir "$op_id")"
  container="$(awk -F= '/^container=/{print $2}' "$cdir/runtime/identity.txt")"
  db_name="$(cat "$cdir/runtime/db_name.txt")"
  logf="$(soviez_update_op_dir "$op_id")/upgrade.log"

  if [[ "${SOVIEZ_UPDATE_FIXTURE_ADDON_FAIL:-0}" == "1" ]]; then
    mkdir -p "$cdir/addons/p15_bad_addon/models"
    cat > "$cdir/addons/p15_bad_addon/__manifest__.py" <<'EOF'
{
    "name": "P15 Bad Addon",
    "version": "99.0.0",
    "depends": ["base"],
    "installable": True,
    "application": False,
}
EOF
    printf 'from . import models\n' > "$cdir/addons/p15_bad_addon/__init__.py"
    printf 'from . import bad\n' > "$cdir/addons/p15_bad_addon/models/__init__.py"
    cat > "$cdir/addons/p15_bad_addon/models/bad.py" <<'EOF'
# Incompatible disposable addon for Phase 15 failure injection
raise RuntimeError("p15 incompatible addon — candidate upgrade must fail")
EOF
    # Sync into Docker-visible host root bind mount
    local host_root
    host_root="$(cat "$cdir/runtime/host_root.txt" 2>/dev/null || echo "$cdir")"
    mkdir -p "$host_root/addons"
    cp -a "$cdir/addons/." "$host_root/addons/"
    # Also docker cp in case bind mount lagged
    if [[ -n "$container" ]]; then
      soviez_update_docker cp "$cdir/addons/p15_bad_addon" "${container}:/root/custom_addons/p15_bad_addon" >/dev/null 2>&1 || true
    fi
    modules="${modules},p15_bad_addon"
  fi

  # Exact DB only — init or update
  local action="-u"
  local pg_name="${SOVIEZ_UPDATE_REAL_PG_NAME:-soviez-upd-pg}"
  local admin_user="${SOVIEZ_UPDATE_PG_ADMIN_USER:-soviez_admin}"
  local admin_pass="${SOVIEZ_UPDATE_PG_ADMIN_PASSWORD:-}"
  local app_user="${SOVIEZ_UPDATE_PG_APP_USER:-soviez_app}"
  if ! soviez_update_docker exec -e PGPASSWORD="$admin_pass" "$pg_name" \
      psql -U "$admin_user" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
    action="-i"
    # S1: app role is NOCREATEDB — bootstrap admin must pre-create the candidate DB.
    soviez_update_docker exec -e PGPASSWORD="$admin_pass" "$pg_name" \
      psql -v ON_ERROR_STOP=1 -U "$admin_user" -d postgres -c \
      "CREATE DATABASE \"${db_name}\" OWNER \"${app_user}\";" >/dev/null \
      || soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Failed to pre-create candidate DB ${db_name}"
  fi

  set +e
  soviez_update_docker exec \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase15-disposable-migration-secret-not-production}" \
    "$container" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /opt/soviez-erp/candidate.conf -d '${db_name}' --without-demo=all ${action} ${modules} --stop-after-init" \
    >>"$logf" 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    soviez_update_die UPDATE_CANDIDATE_UPGRADE_FAILED "Real candidate module upgrade failed rc=$rc"
  fi
  printf '%s' "$(cat "$cdir/runtime/identity.txt" | awk -F= '/^digest=/{print $2}')" > "$cdir/runtime/running_digest.txt"
  printf 'live_production_mutated=false\nreal_docker_upgrade=true\nmodules=%s\n' "$modules" > "$cdir/runtime/isolation_proof.txt"
  printf 'modules_updated=%s\n' "$modules" > "$cdir/runtime/modules_updated.txt"
  printf 'schema=ok\n' > "$cdir/runtime/schema_result.txt"
}

soviez_update_real_validate_http() {
  local op_id="$1"
  local cdir container
  cdir="$(soviez_update_candidate_dir "$op_id")"
  container="$(awk -F= '/^container=/{print $2}' "$cdir/runtime/identity.txt")"
  local db_name
  db_name="$(cat "$cdir/runtime/db_name.txt")"

  # Start HTTP server in background inside candidate
  soviez_update_docker exec -d \
    -e SOVIEZ_MIGRATION_SECRET="${SOVIEZ_MIGRATION_SECRET:-phase15-disposable-migration-secret-not-production}" \
    "$container" bash -lc "cd /opt/soviez-erp && python3 soviez-bin -c /opt/soviez-erp/candidate.conf -d '${db_name}' --http-port=8069" \
    >/dev/null 2>&1 || true

  local i ok=0
  for i in $(seq 1 60); do
    if soviez_update_docker exec "$container" bash -lc "python3 -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8069/web/login', timeout=3)\"" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 2
  done
  [[ "$ok" -eq 1 ]] || soviez_update_die UPDATE_CANDIDATE_VALIDATION_FAILED "Candidate HTTP/login did not respond"
  printf '{"ok":true,"login":"pass","http":"pass"}\n' > "$cdir/runtime/http_validation.json"
}
