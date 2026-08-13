# shellcheck shell=bash
# Phase 12 DNS/ACME challenge lifecycle (signed binding; no DNS-provider mutation).

soviez_ssl_challenge_create() {
  local env_id="$1"
  local domain="$2"
  local host="$3"
  local operation_id="$4"
  local cert_mode="$5"
  local provider="$6"
  local challenge_type="${7:-dns-01}"
  local wildcard_scope="${8:-}"

  soviez_ssl_paths_init
  local challenge_id nonce now exp
  challenge_id="$(soviez_op_generate_id)"
  nonce="$(openssl rand -hex 16)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  exp="$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"

  local path sig_payload
  path="$SOVIEZ_SSL_CHALLENGE_DIR/${challenge_id}.json"
  sig_payload="${env_id}|${domain}|${host}|${operation_id}|${cert_mode}|${provider}|${challenge_type}|${nonce}|${wildcard_scope}"
  local digest
  digest="$(printf '%s' "$sig_payload" | openssl dgst -sha256 | awk '{print $NF}')"

  ENV_ID="$env_id" DOMAIN="$domain" HOST="$host" OP="$operation_id" MODE="$cert_mode" \
    PROV="$provider" CTYPE="$challenge_type" NONCE="$nonce" CID="$challenge_id" \
    WS="$wildcard_scope" NOW="$now" EXP="$exp" DIGEST="$digest" python3 - <<'PY' > "$path"
import json, os
print(json.dumps({
  "challenge_id": os.environ["CID"],
  "environment_id": os.environ["ENV_ID"],
  "domain": os.environ["DOMAIN"],
  "host": os.environ["HOST"],
  "operation_id": os.environ["OP"],
  "certificate_mode": os.environ["MODE"],
  "acme_provider": os.environ["PROV"],
  "challenge_type": os.environ["CTYPE"],
  "nonce": os.environ["NONCE"],
  "issued_at": os.environ["NOW"],
  "expires_at": os.environ["EXP"],
  "wildcard_scope": os.environ.get("WS") or None,
  "binding_digest": os.environ["DIGEST"],
  "status": "pending",
  "consumed": False
}, indent=2))
PY
  chmod 600 "$path"
  # No automatic DNS-provider mutation — operator places token manually if required.
  printf '%s\n' "$challenge_id"
}

soviez_ssl_challenge_load() {
  local challenge_id="$1"
  local path="$SOVIEZ_SSL_CHALLENGE_DIR/${challenge_id}.json"
  [[ -f "$path" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_DNS_CHALLENGE_EXPIRED" "Challenge not found"
  cat "$path"
}

soviez_ssl_challenge_verify_binding() {
  local challenge_id="$1"
  local env_id="$2"
  local domain="$3"
  local host="$4"
  local operation_id="$5"
  local rec
  rec="$(soviez_ssl_challenge_load "$challenge_id")"

  local consumed
  consumed="$(soviez_json_get "$rec" consumed)"
  if [[ "$consumed" == "True" || "$consumed" == "true" ]]; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_DNS_CHALLENGE_REPLAY" "Challenge already consumed"
  fi

  # Expiry check (ISO compare via python)
  local expired
  expired="$(REC="$rec" python3 - <<'PY'
import json, os, time
from datetime import datetime, timezone
rec = json.loads(os.environ["REC"])
exp = datetime.strptime(rec["expires_at"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
print("1" if datetime.now(timezone.utc) > exp else "0")
PY
)"
  [[ "$expired" == "0" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_DNS_CHALLENGE_EXPIRED" "Challenge expired"

  local c_env c_dom c_host c_op
  c_env="$(soviez_json_get "$rec" environment_id)"
  c_dom="$(soviez_json_get "$rec" domain)"
  c_host="$(soviez_json_get "$rec" host)"
  c_op="$(soviez_json_get "$rec" operation_id)"
  if [[ "$c_env" != "$env_id" || "$c_dom" != "$domain" || "$c_host" != "$host" || "$c_op" != "$operation_id" ]]; then
    soviez_ssl_die "$SOVIEZ_SSL_CODE_DNS_CHALLENGE_BINDING_MISMATCH" "Challenge binding mismatch"
  fi

  # Recompute digest
  local nonce ctype mode provider ws expected actual
  nonce="$(soviez_json_get "$rec" nonce)"
  ctype="$(soviez_json_get "$rec" challenge_type)"
  mode="$(soviez_json_get "$rec" certificate_mode)"
  provider="$(soviez_json_get "$rec" acme_provider)"
  ws="$(soviez_json_get "$rec" wildcard_scope 2>/dev/null || true)"
  expected="$(soviez_json_get "$rec" binding_digest)"
  actual="$(printf '%s' "${env_id}|${domain}|${host}|${operation_id}|${mode}|${provider}|${ctype}|${nonce}|${ws}" | openssl dgst -sha256 | awk '{print $NF}')"
  [[ "$expected" == "$actual" ]] || soviez_ssl_die "$SOVIEZ_SSL_CODE_DNS_CHALLENGE_BINDING_MISMATCH" "Challenge tampered"

  # Wildcard scope
  if [[ -n "$ws" && "$ws" != "None" && "$ws" != "null" ]]; then
    case "$domain" in
      ${ws}|*.${ws#\*.}) ;;
      *)
        if [[ "$domain" != "$ws" && "$domain" != *".${ws#\*.}" ]]; then
          soviez_ssl_die "$SOVIEZ_SSL_CODE_WILDCARD_SCOPE_MISMATCH" "Domain outside wildcard scope"
        fi
        ;;
    esac
  fi
}

soviez_ssl_challenge_consume() {
  local challenge_id="$1"
  local path="$SOVIEZ_SSL_CHALLENGE_DIR/${challenge_id}.json"
  local rec
  rec="$(soviez_ssl_challenge_load "$challenge_id")"
  printf '%s\n' "$rec" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["consumed"]=True; d["status"]="consumed"; print(json.dumps(d, indent=2))' > "${path}.tmp"
  mv -f "${path}.tmp" "$path"
  chmod 600 "$path"
}

soviez_ssl_challenge_abort() {
  local challenge_id="$1"
  local path="$SOVIEZ_SSL_CHALLENGE_DIR/${challenge_id}.json"
  [[ -f "$path" ]] || return 0
  local rec
  rec="$(cat "$path")"
  printf '%s\n' "$rec" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["status"]="aborted"; d["consumed"]=True; print(json.dumps(d, indent=2))' > "${path}.tmp"
  mv -f "${path}.tmp" "$path"
}
