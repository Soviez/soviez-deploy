# shellcheck shell=bash

soviez_migration_domain_abort() {
  local pair_id="${1:-}"
  soviez_migration_paths_init
  soviez_migration_assert_no_transfer

  local zone_dir owner_marker preserved=1
  zone_dir="$(soviez_migration_dns_fixture_zone_dir)"
  owner_marker="$zone_dir/owner_dns_marker.txt"
  if [[ -f "$owner_marker" ]]; then preserved=1; fi

  # Abort active DNS challenges (provider-created only)
  if [[ -d "$SOVIEZ_MIG_DNS_CHALLENGE_DIR" ]]; then
    SOVIEZ_PAIR="$pair_id" SOVIEZ_D="$SOVIEZ_MIG_DNS_CHALLENGE_DIR" python3 - <<'PY' | while read -r cid; do
import json, os, pathlib
root=pathlib.Path(os.environ["SOVIEZ_D"])
for p in root.glob("*/object.json"):
  try: d=json.loads(p.read_text())
  except Exception: continue
  if d.get("migration_pair_id")!=os.environ["SOVIEZ_PAIR"]: continue
  if d.get("status") in ("pending","verified"): print(d.get("challenge_id") or p.parent.name)
PY
      [[ -n "$cid" ]] && soviez_migration_dns_challenge_abort "$cid" >/dev/null || true
    done
  fi

  local migration_fqdn
  migration_fqdn="$(soviez_json_get "$(soviez_migration_load_pair "$pair_id" 2>/dev/null || echo '{}')" migration_fqdn 2>/dev/null || true)"
  [[ -n "$migration_fqdn" && "$migration_fqdn" != "null" ]] && \
    soviez_migration_tls_revoke "$pair_id" "$migration_fqdn" >/dev/null || true
  soviez_migration_landing_cleanup "$pair_id" >/dev/null || true

  local ops_dir="$SOVIEZ_MIG_DOMAIN_OPS_DIR/$pair_id"
  mkdir -p "$ops_dir"
  printf '{"pair_id":"%s","status":"aborted","owner_dns_marker_preserved":%s,"production_domain_mutation_allowed":false}\n' \
    "$pair_id" "$preserved" > "$ops_dir/abort.json"

  printf '{"pair_id":"%s","status":"domain_aborted","owner_dns_preserved":true,"migration_token_consumed":false,"destination_production_activated":false}\n' "$pair_id"
}
