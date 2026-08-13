#!/usr/bin/env bash
# Phase 13 — Stage retention unit tests (calendar, extension, Safe Shield, banner).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/helpers/assert.sh
source "$ROOT/tests/helpers/assert.sh"
bash "$ROOT/build/assemble.sh" >/dev/null
# shellcheck source=/dev/null
source "$ROOT/dist/soviez.sh"

export SOVIEZ_TEST_MODE=1
export SOVIEZ_RETENTION_HOST_TZ=UTC
export SOVIEZ_ROOT
SOVIEZ_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/soviez-p13-unit.XXXXXX")"
soviez_paths_init
soviez_stage_paths_init
mkdir -p "$SOVIEZ_ROOT"
printf 'ok\n' > "$SOVIEZ_ROOT/production.ok"

# --- Calendar math ---
created="2026-08-01T12:00:00Z"
d14="$(soviez_retention_add_calendar_days_utc "$created" 14)"
d60="$(soviez_retention_add_calendar_days_utc "$created" 60)"
assert_eq "2026-08-15T23:59:59Z" "$d14"
assert_eq "2026-09-30T23:59:59Z" "$d60"

# Leap year
leap="$(soviez_retention_add_calendar_days_utc "2024-02-20T10:00:00Z" 14)"
assert_eq "2024-03-05T23:59:59Z" "$leap"

# Year boundary
yb="$(soviez_retention_add_calendar_days_utc "2025-12-20T01:00:00Z" 14)"
assert_eq "2026-01-03T23:59:59Z" "$yb"

# Days remaining
export SOVIEZ_RETENTION_NOW_UTC="2026-08-01T12:00:00Z"
assert_eq "14" "$(soviez_retention_days_remaining "$d14")"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-08T12:00:00Z"
assert_eq "7" "$(soviez_retention_days_remaining "$d14")"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-14T12:00:00Z"
assert_eq "1" "$(soviez_retention_days_remaining "$d14")"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-15T12:00:00Z"
assert_eq "0" "$(soviez_retention_days_remaining "$d14")"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-16T12:00:00Z"
assert_eq "-1" "$(soviez_retention_days_remaining "$d14")"

assert_eq "1 day remaining" "$(soviez_retention_remaining_phrase 1)"
assert_eq "2 days remaining" "$(soviez_retention_remaining_phrase 2)"
assert_eq "Deletion scheduled today" "$(soviez_retention_remaining_phrase 0)"
assert_eq "Deletion overdue — Needs Action" "$(soviez_retention_remaining_phrase -1)"

# --- Fixture stage helper ---
make_stage() {
  local sid="$1"
  local created_at="${2:-2026-08-01T12:00:00Z}"
  export SOVIEZ_RETENTION_NOW_UTC="$created_at"
  mkdir -p "$(soviez_stage_dir "$sid")/filestore" "$(soviez_stage_dir "$sid")/config" "$(soviez_stage_dir "$sid")/secrets"
  mkdir -p "$SOVIEZ_ROOT/stage-dbs/$(soviez_stage_db_name_for "$sid")"
  printf 'data\n' > "$(soviez_stage_filestore_path "$sid")/blob"
  printf '{"ok":true,"stage_id":"%s"}\n' "$sid" > "$(soviez_stage_origin_cert_file "$sid")"
  printf '%s\n' "$sid" > "$(soviez_stage_dir "$sid")/config/nginx.owned"
  local identity
  identity="$(python3 - <<PY
import json
print(json.dumps({
  "stage_id": "$sid",
  "parent_production_tenant_id": "tenant-prod-1",
  "license_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "production_fingerprint": "prod_fp_1",
  "source_database_uuid": "db-uuid-prod-1",
  "stage_database_uuid": "db-uuid-$sid",
  "stage_db_name": "$(soviez_stage_db_name_for "$sid")",
  "stage_container": "$(soviez_stage_container_name_for "$sid")",
  "stage_mac": "02:11:22:33:44:55",
  "stage_network": "$(soviez_stage_network_name_for "$sid")",
  "stage_domain": "$sid.example.test",
  "stage_filestore_path": "$(soviez_stage_filestore_path "$sid")",
  "stage_config_path": "$(soviez_stage_config_path "$sid")",
  "stage_secrets_path": "$(soviez_stage_secrets_path "$sid")",
  "origin_certificate_path": "$(soviez_stage_origin_cert_file "$sid")",
  "lifecycle_status": "certified",
  "created_at": "$created_at",
}, separators=(",", ":")))
PY
)"
  soviez_stage_inventory_atomic_write "$(soviez_stage_identity_file "$sid")" "$identity"
  local idx
  idx="$(soviez_stage_inventory_load_index)"
  new_index="$(SOVIEZ_IDX="$idx" SOVIEZ_SID="$sid" python3 - <<'PY'
import json,os
idx=json.loads(os.environ["SOVIEZ_IDX"])
stages=idx.setdefault("stages",[])
stages=[s for s in stages if s.get("stage_id")!=os.environ["SOVIEZ_SID"]]
stages.append({"stage_id": os.environ["SOVIEZ_SID"], "stage_domain": os.environ["SOVIEZ_SID"]+".example.test"})
idx["stages"]=stages
print(json.dumps(idx, separators=(",",":")))
PY
)"
  soviez_stage_inventory_atomic_write "$(soviez_stage_inventory_index)" "$new_index"
  soviez_retention_init_for_stage "$sid" "$created_at"
}

make_stage stagea "2026-08-01T12:00:00Z"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-01T15:00:00Z"
soviez_retention_refresh_derived stagea
rec="$(soviez_retention_read stagea)"
assert_eq "14" "$(soviez_json_get "$rec" days_remaining)"
assert_eq "2026-08-15T23:59:59Z" "$(soviez_json_get "$rec" current_retention_deadline)"
assert_eq "2026-09-30T23:59:59Z" "$(soviez_json_get "$rec" maximum_retention_deadline)"

# Restart does not move deadline
export SOVIEZ_RETENTION_NOW_UTC="2026-08-05T15:00:00Z"
soviez_retention_refresh_derived stagea
assert_eq "2026-08-15T23:59:59Z" "$(soviez_json_get "$(soviez_retention_read stagea)" current_retention_deadline)"

# --- Extensions ---
export SOVIEZ_RETENTION_EXTEND_CONFIRM=stagea
soviez_retention_extend stagea 30 --yes >/dev/null
assert_eq "30" "$(soviez_json_get "$(soviez_retention_read stagea)" requested_extension_days)"
assert_eq "2026-08-31T23:59:59Z" "$(soviez_json_get "$(soviez_retention_read stagea)" current_retention_deadline)"

soviez_retention_extend stagea 60 --yes >/dev/null
assert_eq "2026-09-30T23:59:59Z" "$(soviez_json_get "$(soviez_retention_read stagea)" current_retention_deadline)"
# Idempotent 60
soviez_retention_extend stagea 60 --yes >/dev/null

if ( soviez_retention_extend stagea 61 --yes ) 2>/dev/null; then
  echo "61 days must fail" >&2; exit 1
fi
if ( soviez_retention_extend stagea 14 --yes ) 2>/dev/null; then
  echo "reduction must fail" >&2; exit 1
fi

# --- Banner ---
export SOVIEZ_RETENTION_NOW_UTC="2026-08-08T12:00:00Z"
# After extend to 60, days remaining from Aug 8 to Sep 30 = 53
banner="$(soviez_retention_render_banner stagea)"
assert_contains "$banner" "Stage environment · Neutralized"
assert_contains "$banner" "days remaining"
assert_contains "$banner" "Scheduled deletion"
assert_file_exists "$(soviez_retention_banner_file stagea)"
assert_file_exists "$(soviez_retention_banner_html_file stagea)"

# Reset to default 14 for countdown phrases — new stage
make_stage stageb "2026-08-01T12:00:00Z"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-14T12:00:00Z"
banner="$(soviez_retention_render_banner stageb)"
assert_contains "$banner" "1 day remaining"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-15T12:00:00Z"
banner="$(soviez_retention_render_banner stageb)"
assert_contains "$banner" "Deletion scheduled today"

# Warnings idempotent
export SOVIEZ_RETENTION_NOW_UTC="2026-08-08T12:00:00Z"
soviez_retention_evaluate_warnings stageb
soviez_retention_evaluate_warnings stageb
wc="$(grep -c '"threshold":7' "$(soviez_retention_warnings_file stageb)" || true)"
assert_eq "1" "$wc"

# --- Safe Shield ---
export SOVIEZ_RETENTION_HOLDING_LOCK=1
out="$(soviez_retention_safe_shield_validate stagea)"
assert_eq "OK" "$out"

# Production DB collision
ident="$(soviez_stage_inventory_find stagea)"
soviez_stage_inventory_update_field stagea '{"stage_db_name":"odoo"}'
if soviez_retention_safe_shield_validate stagea >/dev/null 2>&1; then
  echo "prod db collision must fail" >&2; exit 1
fi
soviez_stage_inventory_update_field stagea "{\"stage_db_name\":\"$(soviez_stage_db_name_for stagea)\"}"

# Symlink to production
rm -rf "$(soviez_stage_filestore_path stagea)"
ln -s /var/lib/odoo "$(soviez_stage_filestore_path stagea)"
if soviez_retention_safe_shield_validate stagea >/dev/null 2>&1; then
  echo "symlink must fail" >&2; exit 1
fi
rm -f "$(soviez_stage_filestore_path stagea)"
mkdir -p "$(soviez_stage_filestore_path stagea)"

# Wrong container
soviez_stage_inventory_update_field stagea '{"stage_container":"odoo"}'
if soviez_retention_safe_shield_validate stagea >/dev/null 2>&1; then
  echo "prod container must fail" >&2; exit 1
fi
soviez_stage_inventory_update_field stagea "{\"stage_container\":\"$(soviez_stage_container_name_for stagea)\"}"
unset SOVIEZ_RETENTION_HOLDING_LOCK

# --- Tamper max deadline ---
make_stage stagec "2026-08-01T12:00:00Z"
export SOVIEZ_RETENTION_NOW_UTC="2026-10-01T12:00:00Z"
# Force corrupt current beyond max via raw write
python3 - <<PY
import json
p="$(soviez_retention_file stagec)"
with open(p) as f: d=json.load(f)
d["current_retention_deadline"]="2026-12-01T23:59:59Z"
with open(p,"w") as f: json.dump(d,f,indent=2)
PY
if ( soviez_retention_run_deletion stagec 1 ) 2>/dev/null; then
  echo "beyond-max must fail closed" >&2; exit 1
fi
assert_file_exists "$(soviez_stage_identity_file stagec)"

# --- Backup failure blocks deletion ---
make_stage staged "2026-08-01T12:00:00Z"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-16T12:00:00Z"
export SOVIEZ_RETENTION_INJECT_BACKUP_FAIL=1
if ( soviez_retention_run_deletion staged 0 ) 2>/dev/null; then
  echo "backup fail must block" >&2; exit 1
fi
assert_file_exists "$(soviez_stage_identity_file staged)"
assert_eq "needs_action" "$(soviez_json_get "$(soviez_retention_read staged)" retention_status)"
unset SOVIEZ_RETENTION_INJECT_BACKUP_FAIL

# Retry after fixing backup
export SOVIEZ_RETENTION_RUN_CONFIRM=staged
soviez_retention_retry staged >/dev/null
assert_file_exists "$(soviez_retention_tombstone_file staged)"
[[ ! -d "$(soviez_stage_dir staged)" ]]

# --- Exact deletion preserves sibling ---
make_stage stagex "2026-08-01T12:00:00Z"
make_stage stagey "2026-08-01T12:00:00Z"
export SOVIEZ_RETENTION_NOW_UTC="2026-08-16T12:00:00Z"
soviez_retention_run_deletion stagex 0 >/dev/null
assert_file_exists "$(soviez_stage_identity_file stagey)"
assert_file_exists "$(soviez_retention_tombstone_file stagex)"
[[ ! -d "$(soviez_stage_dir stagex)" ]]

# No global prune strings in engine
assert_not_contains "$(cat "$ROOT/src/stage/retention_engine.sh")" "docker system prune"
assert_not_contains "$(cat "$ROOT/src/stage/retention_engine.sh")" "DROP DATABASE"

echo "test_stage_retention_unit: PASS"
