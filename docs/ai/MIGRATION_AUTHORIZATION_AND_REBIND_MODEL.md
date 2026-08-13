# Migration Authorization and Rebind Model

Phase 20 introduces a **canonical atomic commit** that binds commercial token consumption, license destination binding, source grace, and stage rebind metadata into one signed authorization object. Phase 21 cutover remains unauthorized.

## Dual truth resolution

Two legacy commercial views existed before Phase 20:

| View | Location | Role after Phase 20 |
|------|----------|---------------------|
| Wallet credits | `licenses.ip_migration_credits` / `profiles.ip_migration_credits` | Dual-written on commit; eligibility checks reconcile with grants |
| Grant ledger | `commercial_grants` where `capability_code = migration_token` | **Authoritative** for consume eligibility and `quantity_consumed` |
| Dashboard soft-reserve | `begin_license_migration` | UI compatibility only; installer **must not** call |

**Canonical path:** `commit_migration_authorization` (SaaS RPC `087_migration_authorization_atomic.sql`; fixture mirror `services/migration-authorization-ledger/ledger.py` for certification).

**Blocked paths:** `consume_ip_migration_token`, disconnected `SOVIEZ_MIG_LEGACY_CONSUME`, token burn without `SOVIEZ_MIG_P20_CANONICAL_COMMIT=1`.

## Source of truth

| Environment | SoR |
|-------------|-----|
| Production | SaaS Postgres via `commit_migration_authorization` + `src/lib/migration-authorization/` |
| Certification / TEST_MODE | SQLite fixture ledger at `services/migration-authorization-ledger/ledger.py` |

Local installer stores signed receipts under `$SOVIEZ_MIG_ROOT/authorization/`; it **must not invent** commercial truth.

## Authorization object

Schema: `soviez.migration_authorization.v1`. Emitted atomically on commit with:

- Token consume (`token_quantity_before` → `token_quantity_after`)
- Destination binding transition (license binding moves source → destination fingerprint)
- Source grace record (`migration_origin_grace`)
- Destination status (`production_licensed_pre_cutover`)
- Stage rebind results
- Hard flags: `phase21_allowed=false`, `production_dns_changed=false`, `traffic_cutover_started=false`
- `traffic_owner=source`, `licensed_future_owner=destination`

## Post-commit local apply (saga)

1. **Commit point** — SaaS/fixture ledger (authoritative).
2. **Local apply** — destination binding, source grace, stage rebind, split-brain validation, destination backup marker.
3. **Phase 21 readiness** — PASS / WARNING / BLOCKED report; still `phase21_allowed=false`.

No second token consumption on retry; idempotency keyed by `(account_id, idempotency_key, request_hash)`.

## License rebind semantics

- **One license, one slot:** `slot_count` unchanged; binding fingerprint moves to destination.
- **No second license** created; `license_slots_used` not incremented.
- Source enters `migration_origin_grace`; destination enters `production_licensed_pre_cutover` (internal licensed, no public route).

## Reversal policy

Default: **no automatic refund** on failed local apply after commit. Pre-cutover reversal is deferred/admin-only exceptional (Phase 20 registers op type `migration_pre_cutover_reversal`; not Phase 21 cutover).

## Installer boundary

- Target version: **`0.20.0-phase20`**
- Progress: **95%** until certification PASS, then **96%**
- Phase 21: **UNAUTHORIZED**
