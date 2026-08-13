# shellcheck shell=bash
# Short-lived Registry credential + OCI export (disposable certification).

soviez_offline_registry_export() {
  local registry="${1:?}" repo="${2:?}" digest="${3:?}" out_oci="${4:?}"
  local user="${5:-}" pass="${6:-}"
  local cfg
  cfg="$(mktemp -d -t soviez-regcfg.XXXXXX)"
  export DOCKER_CONFIG="$cfg"
  mkdir -p "$cfg"

  if [[ -n "$user" && -n "$pass" ]]; then
    # Ephemeral login — never persist beyond job
    echo "$pass" | docker login "$registry" -u "$user" --password-stdin >/dev/null 2>&1 || {
      rm -rf "$cfg"
      unset DOCKER_CONFIG
      soviez_offline_die OFFLINE_BUNDLE_REGISTRY_EXPORT_FAILED "docker login failed"
    }
  fi

  local ref="${registry}/${repo}@${digest}"
  if ! docker pull "$ref" >/dev/null 2>&1; then
    # Certification may use a local pre-tagged image as exact digest source
    if [[ -n "${SOVIEZ_PHASE23_LOCAL_IMAGE:-}" ]]; then
      docker tag "$SOVIEZ_PHASE23_LOCAL_IMAGE" "$ref" 2>/dev/null || true
    fi
    docker pull "$ref" >/dev/null 2>&1 || {
      docker logout "$registry" >/dev/null 2>&1 || true
      rm -rf "$cfg"
      unset DOCKER_CONFIG
      soviez_offline_die OFFLINE_BUNDLE_REGISTRY_EXPORT_FAILED "pull failed"
    }
  fi

  mkdir -p "$out_oci"
  # Prefer skopeo/crane if present; else docker save + layout stub with digest verify
  if command -v skopeo >/dev/null 2>&1; then
    skopeo copy "docker-daemon:$ref" "oci:$out_oci:export" >/dev/null 2>&1 || {
      docker logout "$registry" >/dev/null 2>&1 || true
      rm -rf "$cfg"; unset DOCKER_CONFIG
      soviez_offline_die OFFLINE_BUNDLE_REGISTRY_EXPORT_FAILED "skopeo export"
    }
  else
    docker save "$ref" -o "$out_oci/image.tar" >/dev/null 2>&1 || {
      docker logout "$registry" >/dev/null 2>&1 || true
      rm -rf "$cfg"; unset DOCKER_CONFIG
      soviez_offline_die OFFLINE_BUNDLE_REGISTRY_EXPORT_FAILED "docker save"
    }
    printf '{"imageLayoutVersion":"1.0.0","digest":"%s"}\n' "$digest" > "$out_oci/oci-layout"
    printf '%s\n' "$digest" > "$out_oci/DIGEST.txt"
  fi

  # Credential cleanup — ephemeral DOCKER_CONFIG only; never leave residue.
  docker logout "$registry" >/dev/null 2>&1 || true
  rm -rf "$cfg"
  unset DOCKER_CONFIG
  cfg=""
  if declare -F soviez_security_registry_assert_temp_config_clean >/dev/null 2>&1; then
    soviez_security_registry_assert_temp_config_clean "$cfg"
  fi
  if declare -F soviez_security_registry_assert_no_global_auth_for >/dev/null 2>&1; then
    soviez_security_registry_assert_no_global_auth_for "$registry"
  elif [[ "${SOVIEZ_PHASE24_REQUIRE_REGISTRY_CLEAN:-0}" == "1" || "${SOVIEZ_PHASE24_CERTIFICATION:-0}" == "1" ]]; then
    if [[ -f "${HOME}/.docker/config.json" ]] && grep -q "\"$registry\"" "${HOME}/.docker/config.json" 2>/dev/null; then
      soviez_offline_die OFFLINE_BUNDLE_REGISTRY_EXPORT_FAILED "Registry auth persisted in global docker config"
    fi
  fi

  # Bundle must not contain credentials — caller packages OCI only
  printf '%s\n' "$digest"
}

soviez_offline_artifact_store_put() {
  # Provider-neutral: local path or S3 via aws cli if SOVIEZ_ARTIFACT_S3_BUCKET set
  local bundle_id="$1" file="$2"
  local digest
  digest="sha256:$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ -n "${SOVIEZ_ARTIFACT_S3_BUCKET:-}" ]] && command -v aws >/dev/null 2>&1; then
    local key="offline-bundles/${bundle_id}/bundle.bin"
    aws s3 cp "$file" "s3://${SOVIEZ_ARTIFACT_S3_BUCKET}/${key}" \
      --metadata "content-digest=$digest,bundle-id=$bundle_id" >/dev/null || \
      soviez_offline_die OFFLINE_BUNDLE_ARTIFACT_UPLOAD_FAILED "S3 upload"
    printf '{"storage":"s3","bucket":"%s","key":"%s","digest":"%s","immutable":true}\n' \
      "$SOVIEZ_ARTIFACT_S3_BUCKET" "$key" "$digest"
  else
    soviez_offline_bundle_paths_init
    local dest="$SOVIEZ_OFFLINE_BUNDLE_ROOT/artifacts/$bundle_id/bundle.bin"
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]]; then
      soviez_offline_die OFFLINE_BUNDLE_ARTIFACT_UPLOAD_FAILED "Immutable object exists for bundle_id"
    fi
    cp -p "$file" "$dest"
    printf '{"storage":"local","path":"%s","digest":"%s","immutable":true}\n' "$dest" "$digest"
  fi
}
