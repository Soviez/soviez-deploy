# shellcheck shell=bash

soviez_restore_metadata_into_candidate() {
  # Args: op_id production_json backup_object_json
  local op_id="$1" prod="$2" backup="$3"
  local cdir
  cdir="$(soviez_restore_candidate_dir "$op_id")"
  mkdir -p "$cdir/config"
  printf '%s\n' "$prod" > "$cdir/config/production_identity.json"
  printf '%s\n' "$backup" > "$cdir/config/backup_object.json"
  local digest
  digest="$(soviez_json_get "$backup" current_image_digest 2>/dev/null || echo unknown)"
  printf 'digest=%s\n' "$digest" > "$cdir/config/image_digest.txt"
  # Routing refs without private keys
  printf 'nginx_ref=%s\ncert_ref=%s\n' \
    "$(soviez_json_get "$prod" nginx_config_ref 2>/dev/null || echo none)" \
    "$(soviez_json_get "$prod" cert_ref 2>/dev/null || echo none)" \
    > "$cdir/config/routing_refs.txt"
}
