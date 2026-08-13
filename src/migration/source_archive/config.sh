# shellcheck shell=bash

soviez_migration_p22_archive_config() {
  local op_id="$1"
  local src="${SOVIEZ_MIG_P22_SOURCE_CONFIG:-}"
  local out_dir
  out_dir="$(soviez_migration_p22_archive_op_dir "$op_id")/config"
  mkdir -p "$out_dir"
  if [[ -n "$src" && -d "$src" ]]; then
    cp -a "$src/." "$out_dir/" 2>/dev/null || true
  fi
  printf '{"config_archived":true,"secrets_inline":false}\n' > "$out_dir/meta.json"
  cat "$out_dir/meta.json"
}
