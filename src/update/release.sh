# shellcheck shell=bash

soviez_update_release_resolve() {
  local channel="${1:-stable}" requested="${2:-}" current_digest="${3:-}"
  local manifest

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" && -n "${SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON:-}" ]]; then
    if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1 && ! soviez_security_test_bypass_allowed; then
      soviez_update_die UPDATE_RELEASE_NOT_FOUND "Fixture release forbidden outside disposable test env"
    fi
    manifest="$SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON"
  elif [[ -n "$requested" && -f "$requested" ]]; then
    manifest="$(cat "$requested")"
  elif declare -F soviez_registry_resolve_release >/dev/null 2>&1 && [[ "${SOVIEZ_UPDATE_OFFLINE_MODE:-0}" != "1" ]]; then
    local resp
    resp="$(soviez_registry_resolve_release "$channel")"
    manifest="$(soviez_json_get "$resp" release 2>/dev/null || printf '%s' "$resp")"
  else
    soviez_update_die UPDATE_RELEASE_NOT_FOUND "No signed release available"
  fi

  if [[ -n "$requested" && ! -f "$requested" ]]; then
    local rid
    rid="$(soviez_json_get "$manifest" release_id 2>/dev/null || true)"
    [[ "$rid" == "$requested" ]] || {
      # Allow fixture override by release_id filter
      if [[ -n "${SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON:-}" ]]; then
        rid="$(soviez_json_get "$SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON" release_id 2>/dev/null || true)"
        [[ "$rid" == "$requested" ]] || soviez_update_die UPDATE_RELEASE_NOT_FOUND "Requested release not found: $requested"
        manifest="$SOVIEZ_UPDATE_FIXTURE_RELEASE_JSON"
      else
        soviez_update_die UPDATE_RELEASE_NOT_FOUND "Requested release not found: $requested"
      fi
    }
  fi

  printf '%s' "$manifest"
}

soviez_update_release_assert() {
  local manifest="$1" arch="${2:-}" current_digest="${3:-}" erp_major="${4:-}"
  local signed digest signature release_arch release_major release_id notes
  signed="$(soviez_json_get "$manifest" signed 2>/dev/null || echo false)"
  digest="$(soviez_json_get "$manifest" digest 2>/dev/null || soviez_json_get "$manifest" image_digest 2>/dev/null || true)"
  signature="$(soviez_json_get "$manifest" signature 2>/dev/null || true)"
  release_arch="$(soviez_json_get "$manifest" architecture 2>/dev/null || soviez_json_get "$manifest" arch 2>/dev/null || true)"
  release_major="$(soviez_json_get "$manifest" erp_major 2>/dev/null || true)"
  release_id="$(soviez_json_get "$manifest" release_id 2>/dev/null || true)"
  notes="$(soviez_json_get "$manifest" notes_ref 2>/dev/null || true)"

  [[ -n "$digest" && "$digest" != "null" ]] || soviez_update_die UPDATE_RELEASE_DIGEST_MISSING "Release digest missing"
  [[ "$digest" != "latest" && "$digest" != *":latest"* ]] || soviez_update_die UPDATE_RELEASE_DIGEST_MISMATCH "Mutable latest is refused"
  # Phase 24: production-default fail-closed signed release (digest ≠ authorization).
  if declare -F soviez_security_require_signed_manifest >/dev/null 2>&1; then
    soviez_security_require_signed_manifest "$signed" "$signature" "release"
  else
    if [[ "$signed" != "true" && "$signed" != "True" ]]; then
      soviez_update_die UPDATE_RELEASE_UNSIGNED "Release must be signed"
    fi
    if [[ -z "$signature" || "$signature" == "null" || "$signature" == "invalid" || "$signature" == "tampered" ]]; then
      soviez_update_die UPDATE_RELEASE_SIGNATURE_INVALID "Release signature invalid"
    fi
  fi
  if declare -F soviez_security_assert_manifest_crypto >/dev/null 2>&1; then
    soviez_security_assert_manifest_crypto "$manifest"
  elif declare -F soviez_registry_verify_manifest >/dev/null 2>&1; then
    if ! soviez_registry_verify_manifest "$manifest" >/dev/null 2>&1; then
      soviez_update_die UPDATE_RELEASE_SIGNATURE_INVALID "Manifest signature verification failed"
    fi
  fi
  if [[ -n "$arch" && -n "$release_arch" && "$release_arch" != "null" && "$release_arch" != "$arch" ]]; then
    soviez_update_die UPDATE_RELEASE_ARCH_MISMATCH "Architecture mismatch: need $arch got $release_arch"
  fi
  if [[ -n "$erp_major" && -n "$release_major" && "$release_major" != "null" && "$release_major" != "$erp_major" ]]; then
    local allow_jump="${SOVIEZ_UPDATE_ALLOW_MAJOR_JUMP:-0}"
    [[ "$allow_jump" == "1" ]] || soviez_update_die UPDATE_RELEASE_INCOMPATIBLE "ERP major mismatch: $erp_major vs $release_major"
  fi
  if [[ -n "$current_digest" && "$current_digest" == "$digest" ]]; then
    soviez_update_die UPDATE_ALREADY_CURRENT "Already running target digest"
  fi
  # Downgrade detection via version_rank when present
  local cur_rank tgt_rank
  cur_rank="$(soviez_json_get "$manifest" current_version_rank 2>/dev/null || true)"
  tgt_rank="$(soviez_json_get "$manifest" version_rank 2>/dev/null || true)"
  if [[ -n "$cur_rank" && -n "$tgt_rank" && "$tgt_rank" -lt "$cur_rank" ]]; then
    soviez_update_die UPDATE_RELEASE_DOWNGRADE_DENIED "Downgrade denied by policy"
  fi
  printf '%s' "$manifest"
}

soviez_update_acquire_artifact() {
  local op_id="$1" manifest="$2"
  local digest release_id image_ref session
  digest="$(soviez_json_get "$manifest" digest 2>/dev/null || soviez_json_get "$manifest" image_digest)"
  release_id="$(soviez_json_get "$manifest" release_id 2>/dev/null || echo unknown)"
  image_ref="$(soviez_json_get "$manifest" image_ref 2>/dev/null || printf 'soviez/erp@%s' "$digest")"

  local art_dir
  art_dir="$(soviez_update_op_dir "$op_id")/artifact"
  mkdir -p "$art_dir"
  chmod 700 "$art_dir"

  if [[ "${SOVIEZ_UPDATE_OFFLINE_MODE:-0}" == "1" ]]; then
    local pkg_digest
    pkg_digest="$(cat "$(soviez_update_op_dir "$op_id")/offline_digest.txt" 2>/dev/null || true)"
    [[ "$pkg_digest" == "$digest" ]] || soviez_update_die UPDATE_RELEASE_DIGEST_MISMATCH "Offline package digest mismatch"
    printf 'digest=%s\nsource=offline\n' "$digest" > "$art_dir/pull.meta"
    printf '%s' "$digest" > "$art_dir/digest.txt"
    return 0
  fi

  # Local cache hit
  local cache="$SOVIEZ_ROOT/image-cache/$digest"
  if [[ -f "$cache/verified" ]]; then
    local cached
    cached="$(cat "$cache/digest.txt" 2>/dev/null || true)"
    [[ "$cached" == "$digest" ]] || soviez_update_die UPDATE_RELEASE_DIGEST_MISMATCH "Cached digest mismatch"
    printf 'digest=%s\nsource=local_cache\n' "$digest" > "$art_dir/pull.meta"
    printf '%s' "$digest" > "$art_dir/digest.txt"
    return 0
  fi

  # Short-lived pull session via SaaS → Registry Gateway
  local pull_token="" session="" registry_user="" registry_pass="" gateway_url="" fields=""
  if [[ -n "${SOVIEZ_UPDATE_FIXTURE_PULL_SESSION_JSON:-}" ]]; then
    if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1 && ! soviez_security_test_bypass_allowed; then
      soviez_update_die UPDATE_RELEASE_NOT_FOUND "Fixture pull session forbidden outside disposable test env"
    fi
    session="$SOVIEZ_UPDATE_FIXTURE_PULL_SESSION_JSON"
  elif declare -F soviez_registry_create_pull_session >/dev/null 2>&1; then
    session="$(soviez_registry_create_pull_session "$release_id" "$digest" "$op_id" "connected_update")"
  else
    if declare -F soviez_security_test_bypass_allowed >/dev/null 2>&1 && soviez_security_test_bypass_allowed; then
      session='{"ok":true,"pull_ticket":"fixture-token","pull_session_id":"fixture","registry_username":"fixture","repository":"soviez/soviez-erp","digest":"'"$digest"'"}'
    else
      soviez_update_die UPDATE_RELEASE_NOT_FOUND "No Registry pull session available (fixture-token denied in production)"
    fi
  fi

  if declare -F soviez_registry_session_fields >/dev/null 2>&1; then
    fields="$(soviez_registry_session_fields "$session")"
    IFS='|' read -r _sid registry_user registry_pass gateway_url _repo _dig image_ref_from_session <<<"$fields"
    [[ -n "$image_ref_from_session" ]] && image_ref="$image_ref_from_session"
    pull_token="$registry_pass"
  else
    pull_token="$(soviez_json_get "$session" pull_ticket 2>/dev/null || soviez_json_get "$session" token 2>/dev/null || soviez_json_get "$session" pull_token 2>/dev/null || true)"
    registry_user="$(soviez_json_get "$session" registry_username 2>/dev/null || soviez_json_get "$session" pull_session_id 2>/dev/null || echo pull)"
  fi

  local tmp_dockercfg=""
  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    soviez_docker_stub_pull "$image_ref" "$digest"
  elif declare -F soviez_pull_client_run >/dev/null 2>&1 && [[ -n "$registry_pass" || -n "$pull_token" ]]; then
    soviez_pull_client_run "$image_ref" "${registry_user:-pull}" "${registry_pass:-$pull_token}" "$digest" "${gateway_url:-${SOVIEZ_REGISTRY_GATEWAY_URL:-}}"
  else
    tmp_dockercfg="$(mktemp -d "${TMPDIR:-/tmp}/soviez-dockercfg.XXXXXX")"
    export DOCKER_CONFIG="$tmp_dockercfg"
    DOCKER_AUTH_TOKEN="$pull_token" docker pull "$image_ref" >/dev/null 2>&1 || {
      unset pull_token DOCKER_AUTH_TOKEN DOCKER_CONFIG registry_pass
      rm -rf "$tmp_dockercfg"
      soviez_update_die UPDATE_RELEASE_DIGEST_MISMATCH "Digest pull failed"
    }
    unset DOCKER_CONFIG
    rm -rf "$tmp_dockercfg"
    tmp_dockercfg=""
  fi
  unset pull_token DOCKER_AUTH_TOKEN registry_pass
  if declare -F soviez_security_registry_assert_temp_config_clean >/dev/null 2>&1; then
    soviez_security_registry_assert_temp_config_clean "$tmp_dockercfg"
  fi
  mkdir -p "$SOVIEZ_ROOT/image-cache/$digest"
  printf '%s' "$digest" > "$SOVIEZ_ROOT/image-cache/$digest/digest.txt"
  printf 'verified\n' > "$SOVIEZ_ROOT/image-cache/$digest/verified"
  printf 'digest=%s\nsource=registry\n' "$digest" > "$art_dir/pull.meta"
  printf '%s' "$digest" > "$art_dir/digest.txt"
  # Credential cleanup marker (no secrets)
  printf 'cleaned_at=%s\n' "$(soviez_utc_now)" > "$art_dir/credential_cleanup.txt"
}
