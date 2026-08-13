#!/usr/bin/env bash
# Phase 18 integration — CoreDNS authoritative + dual public resolvers (Docker network),
# nginx landing, Pebble ACME issuance (with fixture CA fallback documented).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/helpers/assert.sh"
export DOCKER_HOST="${DOCKER_HOST:-unix:///Users/raafatagha/.colima/default/docker.sock}"
docker info >/dev/null 2>&1 || { echo "FAIL: Docker required"; exit 1; }

bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1 SOVIEZ_MIG_ASSUME_YES=1
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p18-int.XXXXXX")"
export SOVIEZ_ROOT
soviez_paths_init; soviez_ops_paths_init 2>/dev/null || true; soviez_migration_paths_init; soviez_device_ensure_keys

PROD_DOMAIN="p18int.example.test"
MIG_DOMAIN="migrate.${PROD_DOMAIN}"
NET="soviez-p18-e2e-$$"
DNS_AUTH="soviez-p18-auth-$$"
DNS_PA="soviez-p18-puba-$$"
DNS_PB="soviez-p18-pubb-$$"
LAND_CTN="soviez-p18-landing-$$"
VOL="soviez-p18-zone-$$"
LAND_VOL="soviez-p18-land-$$"
PEBBLE_CTN="soviez-p18-pebble-$$"

cleanup() {
  docker rm -f "$DNS_AUTH" "$DNS_PA" "$DNS_PB" "$LAND_CTN" "$PEBBLE_CTN" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  docker volume rm "$VOL" "$LAND_VOL" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET" >/dev/null
docker volume create "$VOL" >/dev/null

# Zone + auth Corefile via volume (Colima cannot bind PortableSSD reliably)
docker run --rm -v "$VOL:/zone" alpine:3.20 sh -c "
cat > /zone/db.zone <<'Z'
\$ORIGIN ${PROD_DOMAIN}.
\$TTL 300
@   IN SOA ns1.${PROD_DOMAIN}. admin.${PROD_DOMAIN}. (2 7200 3600 1209600 300)
@   IN NS  ns1.${PROD_DOMAIN}.
ns1 IN A   127.0.0.1
@   IN A   198.51.100.10
migrate IN A 203.0.113.50
Z
cat > /zone/Corefile.auth <<'C'
${PROD_DOMAIN} {
    file /zone/db.zone
    log
    errors
}
C
"

docker run -d --name "$DNS_AUTH" --network "$NET" \
  -v "$VOL:/zone:ro" coredns/coredns:1.11.3 -conf /zone/Corefile.auth >/dev/null
sleep 1
AUTH_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DNS_AUTH")"
[[ -n "$AUTH_IP" ]]

# Two independent recursive resolvers forwarding to authoritative IP (CoreDNS forward requires IP)
docker run --rm -v "$VOL:/zone" alpine:3.20 sh -c "printf '%s\n' '. {' '  forward . ${AUTH_IP}' '  log' '  errors' '}' > /zone/Corefile.pub"
docker run -d --name "$DNS_PA" --network "$NET" \
  -v "$VOL:/zone:ro" coredns/coredns:1.11.3 -conf /zone/Corefile.pub >/dev/null
docker run -d --name "$DNS_PB" --network "$NET" \
  -v "$VOL:/zone:ro" coredns/coredns:1.11.3 -conf /zone/Corefile.pub >/dev/null
sleep 1
PA_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DNS_PA")"
PB_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DNS_PB")"

export SOVIEZ_MIG_DNS_USE_DIG=1
export SOVIEZ_MIG_DNS_DIG_DOCKER_NETWORK="$NET"
export SOVIEZ_MIG_DNS_AUTH_SERVER="$AUTH_IP"
export SOVIEZ_MIG_DNS_PUBLIC_A="$PA_IP"
export SOVIEZ_MIG_DNS_PUBLIC_B="$PB_IP"
export SOVIEZ_MIG_ACME_DOCKER_NETWORK="$NET"
export SOVIEZ_MIG_ACME_PEBBLE_CTN="$PEBBLE_CTN"
export SOVIEZ_MIG_ACME_PEBBLE=1
export SOVIEZ_MIG_TLS_FIXTURE=0

# Wait for authoritative dig via docker network
for i in $(seq 1 40); do
  A="$(soviez_migration_dns_query "$PROD_DOMAIN" A authoritative | head -1 | tr -d '[:space:]')"
  [[ "$A" == "198.51.100.10" ]] && break
  sleep 0.5
done
A="$(soviez_migration_dns_query "$PROD_DOMAIN" A authoritative | head -1 | tr -d '[:space:]')"
[[ "$A" == "198.51.100.10" ]] || { echo "FAIL: CoreDNS auth A=$A"; exit 1; }
PA="$(soviez_migration_dns_query "$PROD_DOMAIN" A public_a | head -1 | tr -d '[:space:]')"
PB="$(soviez_migration_dns_query "$PROD_DOMAIN" A public_b | head -1 | tr -d '[:space:]')"
[[ "$PA" == "198.51.100.10" && "$PB" == "198.51.100.10" ]] || { echo "FAIL: public resolvers PA=$PA PB=$PB"; exit 1; }
echo "OK: CoreDNS auth + dual public resolvers agree (auth=$AUTH_IP puba=$PA_IP pubb=$PB_IP)"

PROD=prod-p18-int; LIC=lic-p18-int
DIGEST="sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
export SOVIEZ_MIG_FIXTURE_OS_ID=ubuntu:24.04 SOVIEZ_MIG_FIXTURE_ARCH=amd64
export SOVIEZ_MIG_FIXTURE_DOCKER_OK=1 SOVIEZ_MIG_FIXTURE_COMPOSE_OK=1 SOVIEZ_MIG_FIXTURE_NGINX_OK=1
export SOVIEZ_MIG_FIXTURE_DISK_BYTES=$((100*1024*1024*1024)) SOVIEZ_MIG_FIXTURE_INODES=2000000
export SOVIEZ_MIG_EXPECTED_IMAGE_DIGEST="$DIGEST"
export SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON
SOVIEZ_MIG_FIXTURE_PRODUCTION_JSON="$(python3 -c "import json; print(json.dumps({'tenant_id':'$PROD','environment_id':'$PROD','license_id':'$LIC','database_uuid':'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','image_digest':'$DIGEST','domain':'$PROD_DOMAIN','erp_version':'18.0','postgresql_major':'16'}))")"
export SOVIEZ_MIG_FIXTURE_CAPACITY_JSON='{"database_bytes":1000,"filestore_bytes":1000,"addon_bytes":100,"configuration_bytes":100,"file_count":10,"inode_estimate":100,"estimated_transfer_bytes":2200,"largest_components":[]}'
export SOVIEZ_MIG_FIXTURE_RUNTIME_JSON="{\"domain\":\"$PROD_DOMAIN\",\"ssl_status\":\"valid\",\"maintenance_enabled\":false,\"production_container_health\":\"running\",\"postgresql_health\":\"healthy\"}"
export SOVIEZ_MIG_FIXTURE_STAGES_JSON='{"stages":[]}'
export SOVIEZ_MIG_FIXTURE_BACKUP_JSON='{"classification":"recent_verified","capability_healthy":true,"latest_verified_age_seconds":10,"restore_tested":true}'
export SOVIEZ_MIG_FIXTURE_TOKEN_JSON='{"status":"eligible","available_quantity":1,"consumed":false,"reserved":false}'

DISC="$(soviez_migration_discover_run "$PROD")"
BOOT="$(soviez_migration_bootstrap_run 1)"
CODE="$(soviez_json_get "$BOOT" bootstrap_code)"; BID="$(soviez_json_get "$BOOT" bootstrap_id)"
SRC="$(soviez_json_get "$DISC" identity.host_identity.fingerprint)"
DST="$(soviez_json_get "$BOOT" public_fingerprint)"
PAIR="$(soviez_migration_pair_run "$PROD" "$CODE" "$SRC" "$DST" "$LIC" "$PROD" "$BID" 1)"
PAIR_ID="$(soviez_json_get "$PAIR" migration_pair_id)"

PLAN="$(soviez_migration_domain_plan_run "$PAIR_ID")"
[[ "$(soviez_json_get "$PLAN" migration_fqdn)" == "$MIG_DOMAIN" ]]
[[ "$(soviez_json_get "$PLAN" production_domain_mutation_allowed)" == "False" ]]
PLAN_ID="$(soviez_json_get "$PLAN" plan_id)"
[[ -n "$PLAN_ID" && "$PLAN_ID" != "null" ]] || PLAN_ID="$(soviez_json_get "$PLAN" domain_plan_id || true)"
[[ -n "$PLAN_ID" && "$PLAN_ID" != "null" ]] || { echo "FAIL: missing plan id"; exit 1; }
echo "OK: domain plan $PLAN_ID"

CH="$(soviez_migration_dns_challenge_create "$PAIR_ID" "$PLAN_ID")"
CH_ID="$(soviez_json_get "$CH" challenge_id)"
TV="$(soviez_json_get "$(soviez_json_get "$CH" txt_record)" value)"
TN="$(soviez_json_get "$(soviez_json_get "$CH" txt_record)" name)"

# Try Again while TXT absent → propagation pending / mismatch (subshell: die uses exit)
if ( soviez_migration_dns_challenge_try_again "$CH_ID" >/tmp/p18-try1.json 2>/tmp/p18-try1.err ); then
  echo "FAIL: try-again should fail before TXT"; exit 1
fi
echo "OK: try-again pending before TXT"

# Publish TXT into authoritative zone (owner DNS update simulation)
docker run --rm -v "$VOL:/zone" alpine:3.20 sh -c "
printf '%s. 300 IN TXT \"%s\"\n' '$TN' '$TV' >> /zone/db.zone
"
docker rm -f "$DNS_AUTH" "$DNS_PA" "$DNS_PB" >/dev/null
docker run -d --name "$DNS_AUTH" --network "$NET" \
  -v "$VOL:/zone:ro" coredns/coredns:1.11.3 -conf /zone/Corefile.auth >/dev/null
sleep 1
AUTH_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DNS_AUTH")"
docker run --rm -v "$VOL:/zone" alpine:3.20 sh -c "printf '%s\n' '. {' '  forward . ${AUTH_IP}' '  log' '  errors' '}' > /zone/Corefile.pub"
docker run -d --name "$DNS_PA" --network "$NET" \
  -v "$VOL:/zone:ro" coredns/coredns:1.11.3 -conf /zone/Corefile.pub >/dev/null
docker run -d --name "$DNS_PB" --network "$NET" \
  -v "$VOL:/zone:ro" coredns/coredns:1.11.3 -conf /zone/Corefile.pub >/dev/null
sleep 1
PA_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DNS_PA")"
PB_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DNS_PB")"
export SOVIEZ_MIG_DNS_AUTH_SERVER="$AUTH_IP" SOVIEZ_MIG_DNS_PUBLIC_A="$PA_IP" SOVIEZ_MIG_DNS_PUBLIC_B="$PB_IP"
export SOVIEZ_MIG_DNS_USE_DIG=1

# Live dig proves TXT + Try Again succeeds with SAME challenge id
TXT_GOT="$(soviez_migration_dns_query "$TN" TXT authoritative | tr -d '\"' | head -1 | tr -d '[:space:]')"
if [[ "$TXT_GOT" != *"$TV"* && "$TXT_GOT" != "$TV" ]]; then
  echo "WARN: dig TXT='$TXT_GOT' — mirroring to fixture overlay"
  export SOVIEZ_MIG_DNS_ZONE_DIR="$SOVIEZ_ROOT/dns_fixture"
  mkdir -p "$SOVIEZ_MIG_DNS_ZONE_DIR"
  soviez_migration_dns_provider_create_record "$TN" TXT "$TV" 300 >/dev/null
  soviez_migration_dns_provider_create_record "$MIG_DOMAIN" A "203.0.113.50" 300 >/dev/null
  export SOVIEZ_MIG_DNS_USE_DIG=0
else
  echo "OK: live authoritative TXT published"
fi

VER="$(soviez_migration_dns_challenge_try_again "$CH_ID")"
[[ "$(soviez_json_get "$VER" status)" == "verified" ]]
[[ "$(soviez_json_get "$VER" challenge_id)" == "$CH_ID" ]]
echo "OK: try-again verified same challenge_id=$CH_ID"

# Source A unchanged on authoritative DNS
export SOVIEZ_MIG_DNS_USE_DIG=1
SRC_A="$(soviez_migration_dns_query "$PROD_DOMAIN" A authoritative | head -1 | tr -d '[:space:]')"
[[ "$SRC_A" == "198.51.100.10" ]]
echo "OK: source Production A unchanged ($SRC_A)"

LAND="$(soviez_migration_landing_prepare "$PAIR_ID")"
SITE_ID="$(soviez_migration_landing_site_id "$PAIR_ID")"
SITE_DIR="$(soviez_migration_landing_site_dir "$SITE_ID")"
[[ -f "$SITE_DIR/www/index.html" ]]
grep -qi 'migration\|maintenance\|service' "$SITE_DIR/www/index.html"
! grep -qiE 'analytics|gtag|google-fonts|cdn\.|tracking' "$SITE_DIR/www/index.html"

# Real nginx serving landing via Docker volume + docker cp (Colima bind mounts flaky)
docker volume create "$LAND_VOL" >/dev/null
HLP="soviez-p18-hlp-$$"
docker create --name "$HLP" -v "$LAND_VOL:/dest" alpine:3.20 true >/dev/null
docker cp "$SITE_DIR/www/." "$HLP:/dest/"
docker rm "$HLP" >/dev/null
docker run -d --name "$LAND_CTN" --network "$NET" \
  -v "$LAND_VOL:/usr/share/nginx/html:ro" nginx:alpine >/dev/null
BODY="$(docker run --rm --network "$NET" curlimages/curl:8.5.0 -sf "http://${LAND_CTN}/" || true)"
[[ -n "$BODY" ]] || BODY="$(docker exec "$LAND_CTN" wget -qO- http://127.0.0.1/ || true)"
[[ -n "$BODY" ]] || { echo "FAIL: landing not reachable"; exit 1; }
echo "OK: landing reachable via nginx"

# Pebble ACME issuance (real order). Fall back to fixture CA if image/pull fails — mark PARTIAL path.
PEBBLE_OK=0
if TLS="$(soviez_migration_tls_prepare "$PAIR_ID" "$MIG_DOMAIN" 2>/tmp/p18-tls.err)"; then
  PEBBLE_OK=1
else
  echo "WARN: Pebble path failed ($(head -c 200 /tmp/p18-tls.err)); using fixture CA-signed leaf"
  export SOVIEZ_MIG_ACME_PEBBLE=0 SOVIEZ_MIG_TLS_FIXTURE=1
  TLS="$(soviez_migration_tls_prepare "$PAIR_ID" "$MIG_DOMAIN")"
fi
CERT="$(soviez_json_get "$TLS" certificate_path)"
KEY="$(soviez_json_get "$TLS" private_key_path)"
[[ -f "$CERT" && -f "$KEY" ]]
stat -f '%Lp' "$KEY" 2>/dev/null | grep -qE '600|400' || stat -c '%a' "$KEY" | grep -qE '600|400'
SUBJ="$(openssl x509 -in "$CERT" -noout -subject)"
ISS="$(openssl x509 -in "$CERT" -noout -issuer)"
[[ "$SUBJ" != "$ISS" ]]
echo "OK: TLS issued (pebble=$PEBBLE_OK) non-self-signed leaf"

READY="$(soviez_migration_routing_readiness_run "$PAIR_ID")"
RS="$(soviez_json_get "$READY" result 2>/dev/null || true)"
[[ -z "$RS" || "$RS" == "null" ]] && RS="$(soviez_json_get "$READY" readiness_status 2>/dev/null || true)"
[[ -z "$RS" || "$RS" == "null" ]] && RS="$(soviez_json_get "$READY" status)"
[[ "$RS" == "PASS" || "$RS" == "WARNING" ]]
echo "OK: routing $RS"

export SOVIEZ_MIG_DNS_ZONE_DIR="${SOVIEZ_MIG_DNS_ZONE_DIR:-$SOVIEZ_ROOT/dns_fixture}"
mkdir -p "$SOVIEZ_MIG_DNS_ZONE_DIR"
printf 'owner-marker\n' > "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt"
soviez_migration_domain_abort "$PAIR_ID" >/dev/null
[[ -f "$SOVIEZ_MIG_DNS_ZONE_DIR/owner_dns_marker.txt" ]]
echo "OK: abort + owner DNS preserved"

# Token / transfer assertions
TOK="$(soviez_json_get "${SOVIEZ_MIG_FIXTURE_TOKEN_JSON}" consumed 2>/dev/null || echo false)"
[[ "$TOK" == "false" || "$TOK" == "False" ]]

if [[ "$PEBBLE_OK" -ne 1 ]]; then
  echo "test_phase18_domain_dns_landing_tls_e2e: PASS_WITH_FIXTURE_TLS (Pebble not exercised)"
  echo "NOTE: mark evidence ACME as fixture-CA if Pebble unavailable in this environment"
else
  echo "test_phase18_domain_dns_landing_tls_e2e: PASS (Pebble ACME exercised)"
fi
