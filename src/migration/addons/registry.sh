# shellcheck shell=bash

soviez_migration_addons_registry_resolve() {
  local name="$1" version="${2:-}"
  if [[ -n "${SOVIEZ_MIG_FIXTURE_ADDON_DIGEST:-}" ]]; then
    printf '{"name":"%s","version":"%s","digest":"%s","source":"registry_fixture","approved":true}\n' \
      "$name" "$version" "$SOVIEZ_MIG_FIXTURE_ADDON_DIGEST"
    return 0
  fi
  # Deterministic fixture digest from name
  local digest
  digest="$(printf '%s@%s' "$name" "$version" | openssl dgst -sha256 | awk '{print $NF}')"
  printf '{"name":"%s","version":"%s","digest":"sha256:%s","source":"registry_fixture","approved":true}\n' \
    "$name" "$version" "$digest"
}
