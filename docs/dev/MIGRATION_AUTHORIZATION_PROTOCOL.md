# Migration Authorization Protocol

## Scope

Phase 20 installer operations from Phase 19 `ready_for_20` through signed authorization commit and local receipt storage. Excludes DNS cutover, traffic switch, and source deactivation (Phase 21+).

## Preconditions

1. Valid migration pair (Phase 17).
2. Phase 19 transfer complete with `ready_for_20` ∈ {PASS, WARNING}; not BLOCKED.
3. Source write freeze released (`MIGRATION_PHASE19_DRIFT_DETECTED` if active).
4. Staging identity has `public_routing_enabled=false`.
5. Migration token eligible (`migration_token` grant + wallet consistent).

## Operations

| Op | Module | Description |
|----|--------|-------------|
| `migration_authorization_plan` | `authorization/engine.sh` | Read-only plan: revalidates Phase 19 + token eligibility |
| `migration_authorization_commit` | `authorization/engine.sh` | Atomic commit via ledger; requires confirm |
| `migration_authorization_show` | `authorization/engine.sh` | Returns stored receipt |
| `migration_authorization_recover` | `authorization/engine.sh` | Lost-response recovery by op id or idempotency key |

## Commit flow

```text
revalidate_phase19(pair_id)
  → token_eligibility(account, license)
  → build payload + request_hash
  → ledger commit (BEGIN IMMEDIATE / SaaS FOR UPDATE)
  → store authorization.json + op state
```

## Idempotency

- Key: client-supplied `idempotency_key` (default `idem-{operation_id}`).
- Hash: SHA-256 of canonical JSON body (excluding `request_hash` field).
- Same key + same hash → return existing receipt (`idempotent: true`).
- Same key + different hash → `MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT`.

## Gates

`soviez_migration_assert_phase20_authorization_allowed` enforces:

- Allowed op types only.
- `SOVIEZ_MIG_ALLOW_CUTOVER=1` / `SOVIEZ_MIG_DNS_CUTOVER=1` → `MIGRATION_CUTOVER_NOT_AUTHORIZED`
- `SOVIEZ_MIG_ALLOW_TOKEN_CONSUME=1` without canonical commit → blocked
- `SOVIEZ_MIG_LEGACY_CONSUME=1` → blocked

## Receipt invariants

On successful commit:

```text
token_consumed = true
destination_binding_after.fingerprint = dest_fp
source_grace_state = migration_origin_grace
destination_status = production_licensed_pre_cutover
phase21_allowed = false
production_dns_changed = false
traffic_cutover_started = false
```

## Structured codes

See `src/migration/authorization/codes.sh` — e.g. `MIGRATION_AUTHORIZATION_REQUIRED`, `MIGRATION_ACTIVE_OPERATION_CONFLICT`, `MIGRATION_TOKEN_LEDGER_INCONSISTENT`.
