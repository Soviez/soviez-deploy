# shellcheck shell=bash

soviez_migration_dns_instructions_export() {
  local challenge_id="${1:-}" out="${2:-}"
  [[ -n "$challenge_id" ]] || soviez_migration_die MIGRATION_DNS_CHALLENGE_REQUIRED "challenge-id required"
  local challenge
  challenge="$(soviez_migration_dns_challenge_load "$challenge_id")"
  local txt_name txt_value ttl mig_fqdn
  txt_name="$(soviez_json_get "$(soviez_json_get "$challenge" txt_record)" name)"
  txt_value="$(soviez_json_get "$(soviez_json_get "$challenge" txt_record)" value)"
  ttl="$(soviez_json_get "$(soviez_json_get "$challenge" txt_record)" ttl)"
  mig_fqdn="$(soviez_json_get "$challenge" migration_fqdn)"
  local doc
  doc="$(SOVIEZ_TN="$txt_name" SOVIEZ_TV="$txt_value" SOVIEZ_TTL="$ttl" SOVIEZ_MF="$mig_fqdn" \
    SOVIEZ_CID="$challenge_id" python3 - <<'PY'
import json, os
print(json.dumps({
  "challenge_id": os.environ["SOVIEZ_CID"],
  "instructions": [
    {"step": 1, "action": "Create TXT record", "name": os.environ["SOVIEZ_TN"], "value": os.environ["SOVIEZ_TV"], "ttl": int(os.environ["SOVIEZ_TTL"])},
    {"step": 2, "action": "Create A or AAAA or CNAME for migration FQDN", "name": os.environ["SOVIEZ_MF"], "value": "<destination-public-ip-or-target>"},
    {"step": 3, "action": "Wait for propagation", "note": "Two public resolvers must agree with authoritative"},
    {"step": 4, "action": "Run verify", "command": f"soviez.sh --migration-dns-challenge-verify {os.environ['SOVIEZ_CID']}"},
  ],
  "do_not": ["Do not point production apex to destination in Phase 18", "Do not enable source maintenance"],
}, indent=2))
PY
)"
  if [[ -n "$out" ]]; then
    mkdir -p "$(dirname "$out")"
    printf '%s\n' "$doc" > "$out"
    printf '%s\n' "$out"
  else
    printf '%s\n' "$doc"
  fi
}
