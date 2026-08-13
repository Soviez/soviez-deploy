# shellcheck shell=bash

soviez_migration_dns_fixture_zone_dir() {
  printf '%s\n' "${SOVIEZ_MIG_DNS_ZONE_DIR:-${SOVIEZ_MIG_ROOT}/dns_zone_fixture}"
}

soviez_migration_dns_fixture_lookup() {
  local name="$1" rtype="${2:-TXT}" view="${3:-authoritative}"
  local zone_dir base
  zone_dir="$(soviez_migration_dns_fixture_zone_dir)"
  base="$zone_dir/$view/${name}/${rtype}.txt"
  if [[ -f "$base" ]]; then
    cat "$base"
    return 0
  fi
  # Env JSON map fallback: SOVIEZ_MIG_DNS_FIXTURE_<view>_JSON
  local env_key="SOVIEZ_MIG_DNS_FIXTURE_$(printf '%s' "$view" | tr '[:lower:]' '[:upper:]')_JSON"
  local map_json="${!env_key:-}"
  if [[ -n "$map_json" ]]; then
    SOVIEZ_M="$map_json" SOVIEZ_N="$name" SOVIEZ_T="$rtype" python3 - <<'PY'
import json, os, sys
m=json.loads(os.environ["SOVIEZ_M"])
key=f"{os.environ['SOVIEZ_N']}:{os.environ['SOVIEZ_T']}"
vals=m.get(key) or m.get(os.environ["SOVIEZ_N"]) or []
if isinstance(vals, str): vals=[vals]
for v in vals: print(v)
PY
    return $?
  fi
  return 1
}

soviez_migration_dns_dig_raw() {
  local host="$1" port="$2" rtype="$3" name="$4"
  local net="${SOVIEZ_MIG_DNS_DIG_DOCKER_NETWORK:-}"
  if [[ -n "$net" ]] && command -v docker >/dev/null 2>&1; then
    if [[ -n "$port" ]]; then
      docker run --rm --network "$net" alpine:3.20 \
        sh -c "apk add --no-cache bind-tools >/dev/null && dig @$host -p $port +short +time=2 +tries=1 $rtype $name" \
        2>/dev/null || true
    else
      docker run --rm --network "$net" alpine:3.20 \
        sh -c "apk add --no-cache bind-tools >/dev/null && dig @$host +short +time=2 +tries=1 $rtype $name" \
        2>/dev/null || true
    fi
    return 0
  fi
  if [[ -n "$port" ]]; then
    dig @"$host" -p "$port" +short +time=2 +tries=1 "$rtype" "$name" 2>/dev/null || true
  else
    dig @"$host" +short +time=2 +tries=1 "$rtype" "$name" 2>/dev/null || true
  fi
}

soviez_migration_dns_query() {
  local name="$1" rtype="${2:-TXT}" view="${3:-authoritative}"
  if [[ "${SOVIEZ_MIG_DNS_USE_DIG:-0}" == "1" ]] && { command -v dig >/dev/null 2>&1 || [[ -n "${SOVIEZ_MIG_DNS_DIG_DOCKER_NETWORK:-}" ]]; }; then
    local server="" host="" port=""
    case "$view" in
      authoritative) server="${SOVIEZ_MIG_DNS_AUTH_SERVER:-}" ;;
      public_a) server="${SOVIEZ_MIG_DNS_PUBLIC_A:-${SOVIEZ_MIG_DNS_AUTH_SERVER:-}}" ;;
      public_b) server="${SOVIEZ_MIG_DNS_PUBLIC_B:-${SOVIEZ_MIG_DNS_AUTH_SERVER:-}}" ;;
    esac
    if [[ -n "$server" ]]; then
      # host:port (IPv4 / hostname). Docker network dig used when Colima host UDP publish fails.
      if [[ "$server" == *:* && "$server" != *:*:* ]]; then
        host="${server%%:*}"
        port="${server##*:}"
        soviez_migration_dns_dig_raw "$host" "$port" "$rtype" "$name"
      else
        soviez_migration_dns_dig_raw "$server" "" "$rtype" "$name"
      fi
    else
      dig +short +time=2 +tries=1 "$rtype" "$name" 2>/dev/null || true
    fi
    return 0
  fi
  soviez_migration_dns_fixture_lookup "$name" "$rtype" "$view" || true
}

soviez_migration_source_inspect_dns() {
  local production_fqdn="$1"
  local a aaaa cname txt
  a="$(soviez_migration_dns_query "$production_fqdn" A authoritative | tr '\n' ',' | sed 's/,$//')"
  aaaa="$(soviez_migration_dns_query "$production_fqdn" AAAA authoritative | tr '\n' ',' | sed 's/,$//')"
  cname="$(soviez_migration_dns_query "$production_fqdn" CNAME authoritative | tr '\n' ',' | sed 's/,$//')"
  txt="$(soviez_migration_dns_query "$production_fqdn" TXT authoritative | tr '\n' ',' | sed 's/,$//')"
  SOVIEZ_F="$production_fqdn" SOVIEZ_A="$a" SOVIEZ_AAAA="$aaaa" SOVIEZ_C="$cname" SOVIEZ_T="$txt" python3 - <<'PY'
import json, os
print(json.dumps({
  "fqdn": os.environ["SOVIEZ_F"],
  "a": [x for x in os.environ.get("SOVIEZ_A","").split(",") if x],
  "aaaa": [x for x in os.environ.get("SOVIEZ_AAAA","").split(",") if x],
  "cname": [x for x in os.environ.get("SOVIEZ_C","").split(",") if x],
  "txt": [x for x in os.environ.get("SOVIEZ_T","").split(",") if x],
}, separators=(",", ":")))
PY
}

soviez_migration_source_inspect_cert() {
  local production_fqdn="$1"
  if [[ -n "${SOVIEZ_MIG_DNS_FIXTURE_CERT_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_DNS_FIXTURE_CERT_JSON"
    return 0
  fi
  SOVIEZ_F="$production_fqdn" python3 - <<'PY'
import json, os
print(json.dumps({
  "fqdn": os.environ["SOVIEZ_F"],
  "issuer": "fixture-ca",
  "not_after": "2099-01-01T00:00:00Z",
  "status": "valid",
  "mutated": False,
}, separators=(",", ":")))
PY
}

soviez_migration_source_inspect_health() {
  local pair_json="$1"
  if [[ -n "${SOVIEZ_MIG_DNS_FIXTURE_HEALTH_JSON:-}" ]]; then
    printf '%s' "$SOVIEZ_MIG_DNS_FIXTURE_HEALTH_JSON"
    return 0
  fi
  SOVIEZ_P="$pair_json" python3 - <<'PY'
import json, os
p=json.loads(os.environ["SOVIEZ_P"])
print(json.dumps({
  "source_maintenance_enabled": bool(p.get("source_maintenance_enabled")),
  "dns_changed": bool(p.get("dns_changed")),
  "data_transfer_started": bool(p.get("data_transfer_started")),
  "disruption_detected": False,
}, separators=(",", ":")))
PY
}

soviez_migration_source_routing_fingerprint() {
  local dns_json="$1" cert_json="$2" health_json="$3"
  SOVIEZ_D="$dns_json" SOVIEZ_C="$cert_json" SOVIEZ_H="$health_json" python3 - <<'PY'
import json, os, hashlib
parts={
  "dns": json.loads(os.environ["SOVIEZ_D"]),
  "cert": json.loads(os.environ["SOVIEZ_C"]),
  "health": json.loads(os.environ["SOVIEZ_H"]),
}
raw=json.dumps(parts, sort_keys=True, separators=(",", ":"))
print(hashlib.sha256(raw.encode()).hexdigest())
PY
}

soviez_migration_source_inspection_run() {
  local pair_json="$1"
  local prod_fqdn dns cert health fp
  prod_fqdn="$(soviez_migration_domain_production_fqdn "$pair_json")"
  dns="$(soviez_migration_source_inspect_dns "$prod_fqdn")"
  cert="$(soviez_migration_source_inspect_cert "$prod_fqdn")"
  health="$(soviez_migration_source_inspect_health "$pair_json")"
  fp="$(soviez_migration_source_routing_fingerprint "$dns" "$cert" "$health")"
  SOVIEZ_D="$dns" SOVIEZ_C="$cert" SOVIEZ_H="$health" SOVIEZ_F="$fp" SOVIEZ_P="$prod_fqdn" python3 - <<'PY'
import json, os
print(json.dumps({
  "production_fqdn": os.environ["SOVIEZ_P"],
  "dns": json.loads(os.environ["SOVIEZ_D"]),
  "certificate": json.loads(os.environ["SOVIEZ_C"]),
  "health": json.loads(os.environ["SOVIEZ_H"]),
  "source_routing_fingerprint": os.environ["SOVIEZ_F"],
  "read_only": True,
  "mutated": False,
}, separators=(",", ":")))
PY
}
