# shellcheck shell=bash

soviez_migration_addons_package_custom() {
  local src_path="$1" out_path="$2"
  [[ -d "$src_path" || -f "$src_path" ]] || soviez_migration_die MIGRATION_ADDON_NOT_APPROVED "Custom addon path missing"
  # Refuse .git and secret-looking files
  if [[ -d "$src_path/.git" ]]; then
    soviez_migration_die MIGRATION_ADDON_NOT_APPROVED ".git history excluded"
  fi
  mkdir -p "$(dirname "$out_path")"
  if [[ -d "$src_path" ]]; then
    tar -C "$src_path" --exclude='.git' --exclude='*.pem' --exclude='*.key' -cf "$out_path" .
  else
    cp -f "$src_path" "$out_path"
  fi
  local digest
  digest="$(openssl dgst -sha256 "$out_path" | awk '{print $NF}')"
  printf '{"path":"%s","sha256":"%s"}\n' "$out_path" "$digest"
}
