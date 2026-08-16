# shellcheck shell=bash

soviez_docker_stub_pull() {
  local image_ref="$1"
  local digest="$2"
  local marker="$SOVIEZ_ROOT/stubs/docker-pull-$(soviez_sha256_hex "$image_ref" | cut -c1-12).done"
  mkdir -p "$SOVIEZ_ROOT/stubs"
  printf 'image=%s\ndigest=%s\n' "$image_ref" "$digest" > "$marker"
}

soviez_docker_provision_start() {
  local op_id="$1"
  local image_ref="$2"
  local container_name="soviez-web-${op_id}"
  local net="${SOVIEZ_DB_NETWORK:-soviez-net-${op_id}}"
  local host_port="${SOVIEZ_HOST_PORT:-}"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local marker="$SOVIEZ_ROOT/stubs/container-${op_id}.started"
    mkdir -p "$SOVIEZ_ROOT/stubs"
    printf 'container=%s\nimage=%s\n' "$container_name" "$image_ref" > "$marker"
    printf '%s' "$container_name"
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: docker required for container provision" >&2
    return 1
  fi

  docker network create "$net" >/dev/null 2>&1 || true

  local -a publish_args=()
  if [[ -n "$host_port" ]]; then
    local spec
    if declare -F soviez_sec_odoo_loopback_publish_spec >/dev/null 2>&1; then
      spec="$(soviez_sec_odoo_loopback_publish_spec "$host_port")"
    else
      spec="127.0.0.1:${host_port}:8069"
    fi
    publish_args=(-p "$spec")
    # Multi-worker gevent/evented port (loopback only). Host port = http+3 or SOVIEZ_GEVENT_HOST_PORT.
    local gevent_host="${SOVIEZ_GEVENT_HOST_PORT:-}"
    if [[ -z "$gevent_host" && "$host_port" =~ ^[0-9]+$ ]]; then
      gevent_host=$((host_port + 3))
    fi
    if [[ -n "$gevent_host" && "${SOVIEZ_PUBLISH_GEVENT:-1}" == "1" ]]; then
      local gspec
      if declare -F soviez_sec_odoo_loopback_publish_spec >/dev/null 2>&1; then
        gspec="$(soviez_sec_odoo_loopback_publish_spec "$gevent_host" 8072)"
      else
        gspec="127.0.0.1:${gevent_host}:8072"
      fi
      publish_args+=(-p "$gspec")
    fi
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$container_name"; then
    docker start "$container_name" >/dev/null
  else
    # Never privileged, never docker.sock, never host network.
    docker run -d --name "$container_name" --network "$net" \
      "${publish_args[@]}" \
      "$image_ref" sleep infinity >/dev/null
  fi

  if [[ "${SOVIEZ_SEC_PRODUCTION_MARKERS:-0}" == "1" ]] || [[ -f "${SOVIEZ_ROOT:-}/security/production.marker" ]]; then
    export SOVIEZ_SEC_MODE="${SOVIEZ_SEC_MODE:-production}"
    export SOVIEZ_SEC_ODOO_CONTAINER="$container_name"
    export SOVIEZ_SEC_PG_CONTAINER="${SOVIEZ_DB_CONTAINER:-soviez-db-${op_id}}"
    if declare -F soviez_security_validate_critical_containment >/dev/null 2>&1; then
      if docker inspect "$container_name" >/dev/null 2>&1 \
        && docker inspect "${SOVIEZ_SEC_PG_CONTAINER}" >/dev/null 2>&1; then
        SOVIEZ_SEC_PG_ADMIN_PASS="$(soviez_tenant_secret_read pg_admin_password 2>/dev/null || true)"
        SOVIEZ_SEC_PG_APP_PASS="$(soviez_tenant_secret_read db_password 2>/dev/null || true)"
        export SOVIEZ_SEC_PG_ADMIN_PASS SOVIEZ_SEC_PG_APP_PASS
        soviez_security_validate_critical_containment || return 1
      fi
    fi
  fi

  printf '%s' "$container_name"
}
