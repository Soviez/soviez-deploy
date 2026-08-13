# shellcheck shell=bash

# Extract host[:port] from a registry gateway URL for docker login.
soviez_registry_gateway_host() {
  local url="${1:-${SOVIEZ_REGISTRY_GATEWAY_URL:-https://registry.soviez.com}}"
  url="${url#https://}"
  url="${url#http://}"
  url="${url%%/*}"
  printf '%s' "$url"
}

# Assert temporary docker config dir is gone (credential cleanup).
soviez_security_registry_assert_temp_config_clean() {
  local cfg_dir="${1:-}"
  if [[ -n "$cfg_dir" && -e "$cfg_dir" ]]; then
    soviez_die "${SOVIEZ_ERR_API:-20}" "Temporary docker config still present: $cfg_dir"
  fi
  return 0
}

# Pull private image via Registry Gateway using short-lived credentials.
# Args: image_ref registry_user registry_pass expected_digest [gateway_url]
soviez_pull_client_run() {
  local image_ref="$1"
  local registry_user="$2"
  local registry_pass="$3"
  local expected_digest="$4"
  local gateway_url="${5:-${SOVIEZ_REGISTRY_GATEWAY_URL:-https://registry.soviez.com}}"

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    soviez_docker_stub_pull "$image_ref" "$expected_digest"
    return 0
  fi

  local cfg_dir host
  cfg_dir="$(mktemp -d "${TMPDIR:-/tmp}/soviez-docker-config.XXXXXX")"
  chmod 700 "$cfg_dir"
  host="$(soviez_registry_gateway_host "$gateway_url")"

  # Temporary docker auth only — never use ~/.docker/config.json
  if ! printf '%s' "$registry_pass" | DOCKER_CONFIG="$cfg_dir" docker login \
      --username "$registry_user" --password-stdin "$host" >/dev/null 2>&1; then
    rm -rf "$cfg_dir"
    unset registry_pass
    soviez_die "${SOVIEZ_ERR_API:-20}" "Registry gateway login failed"
  fi

  if ! DOCKER_CONFIG="$cfg_dir" docker pull "$image_ref"; then
    DOCKER_CONFIG="$cfg_dir" docker logout "$host" >/dev/null 2>&1 || true
    rm -rf "$cfg_dir"
    unset registry_pass
    soviez_die "${SOVIEZ_ERR_API:-20}" "Registry gateway pull failed"
  fi

  local pulled=""
  pulled="$(DOCKER_CONFIG="$cfg_dir" docker inspect --format='{{index .RepoDigests 0}}' "$image_ref" 2>/dev/null | awk -F@ '{print $2}')"
  if [[ -z "$pulled" ]]; then
    # Fallback: image_ref may already be name@digest
    if [[ "$image_ref" == *@sha256:* ]]; then
      pulled="${image_ref##*@}"
    fi
  fi

  DOCKER_CONFIG="$cfg_dir" docker logout "$host" >/dev/null 2>&1 || true
  rm -rf "$cfg_dir"
  unset registry_pass registry_user
  cfg_dir=""

  soviez_security_registry_assert_temp_config_clean "$cfg_dir"

  if [[ -n "$expected_digest" && "$pulled" != "$expected_digest" ]]; then
    soviez_die "${SOVIEZ_ERR_API:-20}" "Pulled digest mismatch (expected=$expected_digest got=$pulled)"
  fi
}
