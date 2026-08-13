# shellcheck shell=bash

soviez_migration_landing_cleanup() {
  local pair_id="${1:-}"
  soviez_migration_paths_init
  local site_id site_dir
  site_id="$(soviez_migration_landing_site_id "$pair_id")"
  site_dir="$(soviez_migration_landing_site_dir "$site_id")"
  if [[ -d "$site_dir" ]]; then
    rm -rf "$site_dir"
  fi
  printf '{"pair_id":"%s","site_id":"%s","status":"cleaned"}\n' "$pair_id" "$site_id"
}

soviez_migration_landing_prepare() {
  local pair_id="${1:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local pair migration_fqdn production_fqdn site_id site_dir
  pair="$(soviez_migration_load_pair "$pair_id")"
  production_fqdn="$(soviez_migration_domain_production_fqdn "$pair")"
  migration_fqdn="$(soviez_json_get "$pair" migration_fqdn)"
  [[ -n "$migration_fqdn" && "$migration_fqdn" != "null" ]] || \
    migration_fqdn="$(soviez_migration_domain_strategy_default "$production_fqdn")"
  soviez_migration_domain_assert_migration_fqdn "$migration_fqdn" "$production_fqdn"

  site_id="$(soviez_migration_landing_site_id "$pair_id")"
  site_dir="$(soviez_migration_landing_site_dir "$site_id")"
  soviez_migration_landing_write_content "$site_dir" "$pair_id" "$migration_fqdn"
  soviez_migration_landing_write_nginx "$site_dir" "$migration_fqdn"
  soviez_migration_landing_validate_nginx "$site_dir/nginx.conf" "$migration_fqdn" "$production_fqdn"
  soviez_migration_landing_health_check "$site_dir" >/dev/null

  SOVIEZ_PAIR="$pair_id" SOVIEZ_SID="$site_id" SOVIEZ_MF="$migration_fqdn" SOVIEZ_DIR="$site_dir" python3 - <<'PY'
import json, os, datetime, hashlib
root=os.environ["SOVIEZ_DIR"]
idx=open(f"{root}/www/index.html","rb").read()
print(json.dumps({
  "schema_version": "soviez.migration_landing.v1",
  "pair_id": os.environ["SOVIEZ_PAIR"],
  "site_id": os.environ["SOVIEZ_SID"],
  "migration_fqdn": os.environ["SOVIEZ_MF"],
  "content_root": f"{root}/www",
  "nginx_conf": f"{root}/nginx.conf",
  "content_hash": hashlib.sha256(idx).hexdigest(),
  "status": "prepared",
  "created_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}, separators=(",", ":")))
PY
}
