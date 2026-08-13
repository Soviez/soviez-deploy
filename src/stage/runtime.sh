# shellcheck shell=bash
# Stage runtime isolation: container, network, MAC, labels, config.

soviez_stage_runtime_create() {
  local stage_id="$1"
  local image_ref="${2:-soviez/erp:stage-fixture}"
  local identity
  identity="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die STAGE_RUNTIME_FAILED "Missing identity"
  local container network mac db_name domain
  container="$(soviez_json_get "$identity" stage_container)"
  network="$(soviez_json_get "$identity" stage_network)"
  mac="$(soviez_json_get "$identity" stage_mac)"
  db_name="$(soviez_json_get "$identity" stage_db_name)"
  domain="$(soviez_json_get "$identity" stage_domain)"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local marker="$SOVIEZ_ROOT/stubs/stage-runtime-${stage_id}.started"
    mkdir -p "$SOVIEZ_ROOT/stubs"
    cat > "$marker" <<EOF
container=${container}
network=${network}
mac=${mac}
db_filter=^${db_name}$
domain=${domain}
image=${image_ref}
soviez.role=stage
soviez.stage_id=${stage_id}
EOF
    # Ensure dedicated network marker (isolation)
    mkdir -p "$SOVIEZ_ROOT/stubs/networks"
    printf 'network=%s\n' "$network" > "$SOVIEZ_ROOT/stubs/networks/${network}.created"
    printf '%s' "$container"
    return 0
  fi

  if ! docker network inspect "$network" >/dev/null 2>&1; then
    docker network create \
      --label "soviez.role=stage" \
      --label "soviez.stage_id=${stage_id}" \
      "$network" >/dev/null \
      || soviez_stage_die STAGE_RUNTIME_FAILED "Failed to create network $network"
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$container"; then
    soviez_stage_die STAGE_CONTAINER_CONFLICT "Container exists: $container"
  fi

  docker run -d \
    --name "$container" \
    --mac-address "$mac" \
    --network "$network" \
    --label "soviez.role=stage" \
    --label "soviez.stage_id=${stage_id}" \
    --label "soviez.stage_domain=${domain}" \
    --restart unless-stopped \
    -e "SOVIEZ_STAGE=1" \
    -e "SOVIEZ_STAGE_ID=${stage_id}" \
    -e "DB_FILTER=^${db_name}$" \
    "$image_ref" >/dev/null \
    || soviez_stage_die STAGE_RUNTIME_FAILED "docker run failed for $container"

  printf '%s' "$container"
}

soviez_stage_runtime_start() {
  local stage_id="$1"
  local identity container
  identity="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die RECOVERY_REQUIRED "Unknown stage"
  container="$(soviez_json_get "$identity" stage_container)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    touch "$SOVIEZ_ROOT/stubs/stage-runtime-${stage_id}.running"
    soviez_stage_inventory_update_field "$stage_id" '{"lifecycle_status":"running","health_state":"healthy"}'
    return 0
  fi
  docker start "$container" >/dev/null
  soviez_stage_inventory_update_field "$stage_id" '{"lifecycle_status":"running"}'
}

soviez_stage_runtime_stop() {
  local stage_id="$1"
  local identity container
  identity="$(soviez_stage_inventory_find "$stage_id")" || soviez_stage_die RECOVERY_REQUIRED "Unknown stage"
  container="$(soviez_json_get "$identity" stage_container)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    rm -f "$SOVIEZ_ROOT/stubs/stage-runtime-${stage_id}.running"
    touch "$SOVIEZ_ROOT/stubs/stage-runtime-${stage_id}.stopped"
    soviez_stage_inventory_update_field "$stage_id" '{"lifecycle_status":"stopped","health_state":"stopped"}'
    return 0
  fi
  docker stop "$container" >/dev/null
  soviez_stage_inventory_update_field "$stage_id" '{"lifecycle_status":"stopped"}'
}

soviez_stage_runtime_remove_owned() {
  # Removes only Stage-owned container/network markers. Never Production.
  local stage_id="$1"
  local identity container network
  identity="$(soviez_stage_inventory_find "$stage_id" 2>/dev/null || true)"
  [[ -n "$identity" ]] || return 0
  container="$(soviez_json_get "$identity" stage_container)"
  network="$(soviez_json_get "$identity" stage_network)"
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    rm -f "$SOVIEZ_ROOT/stubs/stage-runtime-${stage_id}".*
    rm -f "$SOVIEZ_ROOT/stubs/networks/${network}.created"
    return 0
  fi
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
