# Migration Token Atomic Transaction Protocol

## Principle

One migration token is consumed **if and only if** the full authorization commits atomically: grant decrement, wallet dual-write, binding transition record, source grace record, and signed receipt.

No long-lived reservation. States: **available → atomic lock (transaction) → consumed**.

## Authoritative consume (SaaS)

RPC: `commit_migration_authorization` in `soviez-saas/supabase/migrations/087_migration_authorization_atomic.sql`.

Transaction steps (single Postgres function):

1. `FOR UPDATE` lock license row.
2. Idempotency check (`migration_authorization_idempotency`).
3. `FOR UPDATE` lock `commercial_grants` row (`capability_code = migration_token`).
4. Increment `quantity_consumed`; set grant `exhausted` if depleted.
5. Dual-write wallet: prefer `licenses.ip_migration_credits`, else `profiles.ip_migration_credits`.
6. Insert `migration_authorizations`, binding transition, source grace, stage rebinds, audit.
7. Return `authorization_json` receipt.

## Fixture consume (certification)

`services/migration-authorization-ledger/ledger.py commit`:

- SQLite `BEGIN IMMEDIATE` per license.
- Reconciles `grants.quantity - quantity_consumed` with `wallet.credits`.
- Updates license binding to destination fingerprint.
- Emits `soviez.migration_authorization.v1` body.

## Eligibility (pre-commit)

`eligibility` command / installer `soviez_migration_token_eligibility_p20`:

- Grant remaining ≥ 1
- Wallet credits ≥ 1
- `rem == wallet` (else `MIGRATION_TOKEN_LEDGER_INCONSISTENT`)
- `consumed=false`, `reserved=false`

## Blocked legacy paths

| Path | Result |
|------|--------|
| `consume_ip_migration_token` | Raises `MIGRATION_TOKEN_NOT_ELIGIBLE` |
| `SOVIEZ_MIG_LEGACY_CONSUME=1` | Installer die |
| `begin_license_migration` from installer | Forbidden (dashboard UI only) |

## Exactly-once

- Idempotent replay returns stored receipt without second decrement.
- Concurrent commits for same license → `MIGRATION_ACTIVE_OPERATION_CONFLICT` (second transaction fails).
- Lost response: recover via `get_migration_authorization_by_idempotency` / ledger `get`.

## Installer integration

`soviez_migration_authorization_commit` sets `SOVIEZ_MIG_P20_CANONICAL_COMMIT=1` before ledger call.
