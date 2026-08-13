# shellcheck shell=bash

soviez_migration_dns_challenge_abort() {
  local challenge_id="${1:-}"
  soviez_migration_paths_init
  local path provider_created txt_name
  path="$(soviez_migration_dns_challenge_dir "$challenge_id")/object.json"
  if [[ ! -f "$path" ]]; then
    printf '{"challenge_id":"%s","status":"aborted"}\n' "$challenge_id"
    return 0
  fi
  provider_created="$(soviez_json_get "$(cat "$path")" provider_created)"
  txt_name="$(soviez_json_get "$(soviez_json_get "$(cat "$path")" txt_record)" name)"
  if [[ "$provider_created" == "true" || "$provider_created" == "True" ]]; then
    soviez_migration_dns_provider_delete_record "$txt_name" TXT
  fi
  SOVIEZ_P="$path" python3 - <<'PY'
import json, os
p=os.environ["SOVIEZ_P"]
d=json.load(open(p))
d["status"]="aborted"
d["consumed"]=False
open(p,"w").write(json.dumps(d, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$path"
  printf '{"challenge_id":"%s","status":"aborted","owner_dns_preserved":true}\n' "$challenge_id"
}

# Renew: create a fresh challenge (required after expiry). Does not mutate DNS.
soviez_migration_dns_challenge_renew() {
  local pair_id="${1:-}"
  soviez_migration_paths_init
  local plan_id=""
  plan_id="$(soviez_json_get "$(soviez_migration_load_pair "$pair_id")" domain_plan_id 2>/dev/null || true)"
  [[ -n "$plan_id" && "$plan_id" != "null" ]] || plan_id=""
  soviez_migration_dns_challenge_create "$pair_id" "$plan_id"
}

# Backward-compatible alias used by older tests/CLI — means renew (new challenge id).
soviez_migration_dns_challenge_retry() {
  soviez_migration_dns_challenge_renew "$@"
}

# Try Again: same challenge id while unexpired; re-check DNS; no DNS mutation; no new ACME order.
soviez_migration_dns_challenge_try_again() {
  local challenge_id="${1:-}"
  local challenge path status expires
  soviez_migration_paths_init
  [[ -n "$challenge_id" ]] || soviez_migration_die MIGRATION_DNS_CHALLENGE_REQUIRED "challenge-id required"
  challenge="$(soviez_migration_dns_challenge_load "$challenge_id")"
  path="$(soviez_migration_dns_challenge_dir "$challenge_id")/object.json"
  status="$(soviez_json_get "$challenge" status)"
  expires="$(soviez_json_get "$challenge" expires_at)"

  if [[ "$status" == "verified" ]]; then
    SOVIEZ_P="$path" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_P"]))
d["try_again"]="already_verified"
print(json.dumps(d, separators=(",", ":")))
PY
    return 0
  fi
  if [[ "$status" == "aborted" ]]; then
    soviez_migration_die MIGRATION_DOMAIN_ABORTED "Challenge aborted"
  fi
  if soviez_migration_is_expired "$expires"; then
    soviez_migration_die MIGRATION_DNS_CHALLENGE_EXPIRED "Challenge expired; create a new challenge"
  fi
  # Idempotent re-validation of the exact challenge (no new nonce / no DNS write).
  soviez_migration_dns_challenge_verify "$challenge_id"
}
