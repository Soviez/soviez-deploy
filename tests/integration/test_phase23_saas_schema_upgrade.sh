#!/usr/bin/env bash
# Phase 23 — SaaS schema upgrade proof: stub the pre-090 capability catalog
# state (matching migration 079's real DDL/seed), THEN apply
# 090_offline_update_bundles.sql on a disposable Postgres, and prove:
#   - the offline_update_bundle capability flips product_not_launched -> false
#   - new capability mappings land (addon_slug + grant_type)
#   - offline_bundle_issuances / offline_update_reconciliations exist, are
#     RLS-enabled with service_role policies, and their CHECK constraints
#     genuinely enforce Phase 23 invariants (no network requirement, no
#     ERP disable, single successful apply) — not just "table exists".
#   - the migration is safely re-appliable (idempotent forward migration).
set -euo pipefail
set +o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
SAAS_ROOT="${SAAS_ROOT:-$(cd "$ROOT/../soviez-saas" && pwd)}"
# shellcheck source=/dev/null
source "$ROOT/tests/helpers/phase23_cert.sh"
soviez_phase23_cert_env
soviez_phase23_assert_cert_gates
soviez_phase23_postgres_preflight

[[ -d "$SAAS_ROOT" ]] || { echo "FAIL: soviez-saas not found at $SAAS_ROOT" >&2; exit 1; }
MIG090="$SAAS_ROOT/supabase/migrations/090_offline_update_bundles.sql"
[[ -f "$MIG090" ]] || { echo "FAIL: missing migration 090 at $MIG090" >&2; exit 1; }

DBNAME="p23upgrade"
CID_NAME="soviez-p23-schema-upgrade-$$"
docker rm -f "$CID_NAME" >/dev/null 2>&1 || true
# Deliberately NO --rm: if initdb/readiness fails we need `docker logs`
# against a live container id, not an opaque "No such container" error
# (this is exactly how F04/F08 in PRIOR_FAILURE_LEDGER.md were misdiagnosed
# under disk pressure). Cleanup is explicit via the trap below.
CID="$(docker run -d --name "$CID_NAME" --label soviez.phase23.disposable=1 \
  -e POSTGRES_PASSWORD=p23u -e POSTGRES_DB="$DBNAME" postgres:16-alpine)"
cleanup() { docker rm -f "$CID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== wait for disposable Postgres readiness (bounded, container kept alive on failure) =="
ready=0
for _ in $(seq 1 60); do
  if docker exec "$CID" pg_isready -U postgres >/dev/null 2>&1; then
    ready=1
    break
  fi
  if ! docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null | grep -q true; then
    echo "FAIL: postgres died during readiness" >&2
    docker logs "$CID" 2>&1 | tail -40 >&2 || true
    exit 1
  fi
  sleep 0.5
done
[[ "$ready" -eq 1 ]] || { echo "FAIL: postgres never became ready" >&2; docker logs "$CID" 2>&1 | tail -40 >&2; exit 1; }
echo "[assert] disposable Postgres ready, container=$CID"

# pg_isready only proves the postmaster is accepting connections — wait until
# POSTGRES_DB exists (init scripts finish). Without this, stub SQL can hit
# FATAL: database "p23upgrade" does not exist (exit 2) under load.
db_ready=0
for _ in $(seq 1 60); do
  if docker exec "$CID" psql -U postgres -d "$DBNAME" -c 'SELECT 1' >/dev/null 2>&1; then
    db_ready=1
    break
  fi
  if ! docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null | grep -q true; then
    echo "FAIL: postgres died before database $DBNAME became usable" >&2
    docker logs "$CID" 2>&1 | tail -40 >&2 || true
    exit 1
  fi
  sleep 0.25
done
[[ "$db_ready" -eq 1 ]] || {
  echo "FAIL: database $DBNAME never became usable" >&2
  docker logs "$CID" 2>&1 | tail -40 >&2 || true
  exit 1
}
echo "[assert] database $DBNAME accepting queries"

psqlc() { docker exec -i "$CID" psql -U postgres -d "$DBNAME" -v ON_ERROR_STOP=1 "$@"; }

echo "== stub pre-090 capability catalog (real 079 DDL + seed row) =="
psqlc <<'SQL' >/tmp/p23-upgrade-stub.out
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $$ BEGIN CREATE ROLE anon NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticated NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE service_role NOLOGIN BYPASSRLS; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID LANGUAGE sql STABLE AS $$ SELECT NULL::uuid $$;

CREATE TABLE public.commercial_capabilities (
  code TEXT PRIMARY KEY,
  internal_name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  value_type TEXT NOT NULL,
  target_scope TEXT NOT NULL,
  quantity_behavior TEXT NOT NULL,
  validity_behavior TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE public.commercial_capability_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_kind TEXT NOT NULL,
  source_key TEXT NOT NULL,
  capability_code TEXT NOT NULL REFERENCES public.commercial_capabilities (code),
  grants_quantity INTEGER NOT NULL DEFAULT 1,
  requires_exact_license BOOLEAN NOT NULL DEFAULT FALSE,
  allow_unbound BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT commercial_capability_mappings_unique
    UNIQUE (source_kind, source_key, capability_code)
);

INSERT INTO public.commercial_capabilities (
  code, internal_name, description, value_type, target_scope,
  quantity_behavior, validity_behavior, metadata
) VALUES (
  'offline_update_bundle',
  'Offline Update Bundle',
  'Future offline update bundle access. Foundation seed only.',
  'boolean',
  'license',
  'none',
  'time_bound',
  '{"phase":4,"product_not_launched":true}'::jsonb
);
SQL

echo "== capture pre-090 state =="
BEFORE_LAUNCHED="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT metadata->>'product_not_launched' FROM public.commercial_capabilities WHERE code='offline_update_bundle'")"
[[ "$BEFORE_LAUNCHED" == "true" ]] || { echo "FAIL: pre-090 stub state wrong (product_not_launched=$BEFORE_LAUNCHED)"; exit 1; }
MAPPINGS_BEFORE="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT count(*) FROM public.commercial_capability_mappings")"
echo "[assert] pre-090: offline_update_bundle.product_not_launched=true, mappings=$MAPPINGS_BEFORE"

echo "== apply 090_offline_update_bundles.sql =="
psqlc < "$MIG090" >/tmp/p23-upgrade-090.out
echo "[assert] migration 090 applied without error"

echo "== capability flipped to launched, phase=23 =="
AFTER_LAUNCHED="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT metadata->>'product_not_launched' FROM public.commercial_capabilities WHERE code='offline_update_bundle'")"
AFTER_PHASE="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT metadata->>'phase' FROM public.commercial_capabilities WHERE code='offline_update_bundle'")"
AFTER_DESC="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT description FROM public.commercial_capabilities WHERE code='offline_update_bundle'")"
[[ "$AFTER_LAUNCHED" == "false" ]] || { echo "FAIL: product_not_launched not flipped to false (got '$AFTER_LAUNCHED')"; exit 1; }
[[ "$AFTER_PHASE" == "23" ]] || { echo "FAIL: metadata.phase != 23 (got '$AFTER_PHASE')"; exit 1; }
[[ "$AFTER_DESC" == *"Offline update bundle issuance entitlement"* ]] || { echo "FAIL: description not updated"; exit 1; }
echo "[assert] offline_update_bundle capability launched by migration 090"

echo "== new capability mappings inserted =="
MAP_ANNUAL="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT count(*) FROM public.commercial_capability_mappings WHERE source_kind='addon_slug' AND source_key='technical-support-annual' AND capability_code='offline_update_bundle'")"
MAP_GRANT="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT count(*) FROM public.commercial_capability_mappings WHERE source_kind='grant_type' AND source_key='offline_update_bundle' AND capability_code='offline_update_bundle'")"
[[ "$MAP_ANNUAL" == "1" ]] || { echo "FAIL: annual technical-support -> offline_update_bundle mapping missing"; exit 1; }
[[ "$MAP_GRANT" == "1" ]] || { echo "FAIL: manual grant_type -> offline_update_bundle mapping missing"; exit 1; }
echo "[assert] both new commercial_capability_mappings rows present"

echo "== tables exist: offline_bundle_issuances, offline_update_reconciliations =="
for tbl in offline_bundle_issuances offline_update_reconciliations; do
  exists="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
    "SELECT to_regclass('public.$tbl') IS NOT NULL")"
  [[ "$exists" == "t" ]] || { echo "FAIL: table public.$tbl missing after migration 090"; exit 1; }
done
echo "[assert] both Phase 23 tables exist"

echo "== RLS enabled + service_role policies present =="
for tbl in offline_bundle_issuances offline_update_reconciliations; do
  rls="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
    "SELECT relrowsecurity FROM pg_class WHERE oid = 'public.$tbl'::regclass")"
  [[ "$rls" == "t" ]] || { echo "FAIL: RLS not enabled on public.$tbl"; exit 1; }
  pol="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
    "SELECT count(*) FROM pg_policies WHERE tablename='$tbl' AND policyname='service_role_all_$tbl'")"
  [[ "$pol" == "1" ]] || { echo "FAIL: service_role_all_$tbl policy missing"; exit 1; }
done
echo "[assert] RLS enabled and service_role policy present on both tables"

echo "== offline_bundle_issuances is genuinely usable (real insert, not just present) =="
psqlc <<'SQL' >/tmp/p23-upgrade-insert.out
INSERT INTO public.offline_bundle_issuances (
  issuance_id, authorization_id, bundle_id, account_id, license_id,
  environment_id, device_fingerprint, target_installer_version,
  target_erp_digest, authorization_expiry, apply_expiry
) VALUES (
  'iss-p23-upgrade-1', 'auth-p23-upgrade-1', 'bun-p23-upgrade-1',
  gen_random_uuid(), gen_random_uuid(), 'env-upgrade-1', 'fp-upgrade-1',
  '0.23.0-phase23', 'sha256:' || repeat('a', 64),
  timezone('utc', now()) + interval '1 day',
  timezone('utc', now()) + interval '1 day'
);
SQL
ROW_COUNT="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT count(*) FROM public.offline_bundle_issuances WHERE issuance_id='iss-p23-upgrade-1'")"
[[ "$ROW_COUNT" == "1" ]] || { echo "FAIL: real insert into offline_bundle_issuances did not persist"; exit 1; }
echo "[assert] real row inserted and read back"

echo "== CHECK constraints genuinely enforce Phase 23 invariants (not just documentation) =="
set +e
docker exec -i "$CID" psql -U postgres -d "$DBNAME" -v ON_ERROR_STOP=1 <<'SQL' >/tmp/p23-upgrade-violate.out 2>&1
INSERT INTO public.offline_bundle_issuances (
  issuance_id, authorization_id, bundle_id, account_id, license_id,
  environment_id, device_fingerprint, target_installer_version,
  target_erp_digest, authorization_expiry, apply_expiry,
  network_required_during_apply
) VALUES (
  'iss-p23-should-fail', 'auth-p23-should-fail', 'bun-p23-should-fail',
  gen_random_uuid(), gen_random_uuid(), 'env-fail', 'fp-fail',
  '0.23.0-phase23', 'sha256:' || repeat('b', 64),
  timezone('utc', now()) + interval '1 day',
  timezone('utc', now()) + interval '1 day',
  true
);
SQL
violate_rc=$?
set -e
[[ "$violate_rc" -ne 0 ]] || { echo "FAIL: network_required_during_apply=true was accepted (CHECK constraint not enforced)"; exit 1; }
grep -qi 'network_required_during_apply' /tmp/p23-upgrade-violate.out || { echo "FAIL: rejection was not due to the expected CHECK constraint"; cat /tmp/p23-upgrade-violate.out; exit 1; }
echo "[assert] network_required_during_apply=true rejected by real CHECK constraint"

echo "== offline_update_reconciliations enforces erp_disabled=false =="
set +e
docker exec -i "$CID" psql -U postgres -d "$DBNAME" -v ON_ERROR_STOP=1 <<'SQL' >/tmp/p23-upgrade-violate2.out 2>&1
INSERT INTO public.offline_update_reconciliations (
  receipt_id, bundle_id, account_id, license_id, environment_id,
  device_fingerprint, result, erp_disabled
) VALUES (
  'rcpt-p23-should-fail', 'bun-p23-should-fail', gen_random_uuid(), gen_random_uuid(),
  'env-fail', 'fp-fail', 'success', true
);
SQL
violate2_rc=$?
set -e
[[ "$violate2_rc" -ne 0 ]] || { echo "FAIL: erp_disabled=true was accepted"; exit 1; }
grep -qi 'erp_disabled' /tmp/p23-upgrade-violate2.out || { echo "FAIL: rejection not due to erp_disabled CHECK"; cat /tmp/p23-upgrade-violate2.out; exit 1; }
echo "[assert] erp_disabled=true rejected by real CHECK constraint"

echo "== migration 090 is safely re-appliable (idempotent forward migration) =="
psqlc < "$MIG090" >/tmp/p23-upgrade-090-again.out
ROW_COUNT_AFTER="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT count(*) FROM public.offline_bundle_issuances WHERE issuance_id='iss-p23-upgrade-1'")"
[[ "$ROW_COUNT_AFTER" == "1" ]] || { echo "FAIL: re-applying migration 090 lost or duplicated existing data"; exit 1; }
MAP_ANNUAL_AGAIN="$(docker exec "$CID" psql -U postgres -d "$DBNAME" -Atc \
  "SELECT count(*) FROM public.commercial_capability_mappings WHERE source_kind='addon_slug' AND source_key='technical-support-annual' AND capability_code='offline_update_bundle'")"
[[ "$MAP_ANNUAL_AGAIN" == "1" ]] || { echo "FAIL: re-applying migration 090 duplicated the annual mapping row"; exit 1; }
echo "[assert] migration 090 re-applied cleanly with no data loss or duplication"

docker rm -f "$CID" >/dev/null 2>&1 || true
trap - EXIT
echo "OK test_phase23_saas_schema_upgrade"
exit 0
