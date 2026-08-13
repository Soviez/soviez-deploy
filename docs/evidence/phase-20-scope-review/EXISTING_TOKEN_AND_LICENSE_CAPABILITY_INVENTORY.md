# EXISTING_TOKEN_AND_LICENSE_CAPABILITY_INVENTORY.md

Legend: **R**=reusable, **F**=refactor, **U**=unsafe for Phase 20 as-is, **O**=obsolete, **D**=duplicate/shadow.

## SaaS — commercial / entitlement

| Primitive | Path | Side | Notes |
|-----------|------|------|-------|
| `CAPABILITY_MIGRATION_TOKEN` | `soviez-saas/src/lib/commercial/logic.ts` | SaaS | **R** constant |
| `upsertMigrationTokenGrant` | `…/commercial/index.ts` | SaaS | **R**/shadow; burn does not bump `quantity_consumed` |
| `syncCommercialLedgerForPurchase` | same | SaaS | **R** provider-neutral dual-write |
| `reverseCommercialLedger*` / dispute | same | SaaS | **R** refund/dispute ledger |
| `resolve_capability_entitlement` | `079_capability_entitlement_foundation.sql` | SaaS | **R** eligibility; does **not** replace burn |
| `resolveCapabilityEntitlement*` | `…/entitlements/` | SaaS | **R** |
| `commercial_transactions` / `commercial_grants` / `commercial_grant_allocations` | `078_…sql` | SaaS | **R**; allocations unused for tokens |
| Catalog `migration_token` | `079` | SaaS | Shadow until Phase 20 |
| `grant_ip_migration_tokens` | `011` / hardening | SaaS | **F** wallet grant; not key-idempotent |
| `revoke_ip_migration_tokens` | `044` | SaaS | **F** clawback |
| `consume_ip_migration_token` | `011` | SaaS | **O** immediate debit; no app callers |
| `secure_license_ip_migration` | `015`–`040` lineage | SaaS | **O** superseded by 070 |
| `begin_license_migration` | `070_migration_session_lock.sql` | SaaS | **F**/U — soft-reserves wallet **now**; not commercial-grant atomic |
| `cancel_license_migration` / TTL rollback | `070` | SaaS | **F** restores reserved |
| `migrate_license_ip` | `070` (rewrote 065) | SaaS | **F** completes reserved burn + rebind; no second debit; **no** request idempotency key |
| `POST /api/license/migrate/{begin,cancel,}` | `src/app/api/license/migrate/*` | SaaS | **F** dashboard cookie/OTP; not installer PoP |
| verify-deactivation-receipt | `…/verify-deactivation-receipt` | SaaS | **R** Gate 1 HMAC pattern |
| Slot reservation machine | `082` + `/api/installer/slots/*` | SaaS | **R** idempotency model to copy |
| Stage/Support offline admin-grant | `stage-license/admin-grant.ts` etc. | SaaS | **R** pattern; no dedicated Migration Token offline grant module |

### Transaction / locking (wallet session)

- Soft reserve: debit wallet at `begin`; columns `is_migrating`, `migration_status`, `migration_reserved_at`, `migration_token_source`.
- TTL ~30m stale release.
- **Quantity:** wallet integers; commercial grant quantity shadow-only.
- **Idempotency:** resume pending on same license; **not** slot-style `operation_id`+`idempotency_key`+`request_hash`.
- **Rollback:** cancel/TTL restores credit if pending; after migrate commit, no ordinary cancel.

## SaaS — License slots / binding

| Primitive | Path | Notes |
|-----------|------|-------|
| `reserve_license_slot` / bind / issue / ack | installer slots APIs | **R** first-activation; **not** migrate rebind |
| `generate_secure_license_for_purchase` | SQL | Initial mint; may move profile credits onto license |
| License fingerprint / `server_ip` / `db_uuid` / `license_key` | licenses table | Mutated by `migrate_license_ip` |

## soviez-sh — Migration (17–19)

| Primitive | Path | Notes |
|-----------|------|-------|
| `soviez_migration_token_eligibility` | `src/migration/readiness/engine.sh` | **R** read-only; forces reserved/consumed false |
| `assert_no_transfer` / `assert_no_cutover_or_token` | `src/migration/common/codes.sh` | **U** for burn entry — hard deny; need Phase 20 scoped authorize |
| Pair / bootstrap / mTLS | `pairing/`, `bootstrap/`, `tls/` | **R** targeting |
| Staging identity/validate | `staging/identity.sh`, `validate.sh` | **R** input; forbids public/slot/token-consumed |
| Transfer + `ready_for_20` | `transfer/engine.sh` | **R** handoff contract |
| Phase 19 freeze/staging | `final_sync/`, `staging/` | **R**; freeze must be released before Phase 20 |

## License Guard (ERP)

| Primitive | Path | Notes |
|-----------|------|-------|
| `SOVIEZ_MIGRATION_SECRET` | `local_license_guard` import fail-closed | **R** HMAC; **≠** commercial token |
| Fingerprint / `database.uuid` | `license_tools` | **R** bind validation |
| Staging vs permanent bind | Phase 15/19 contracts | **F** need `production_licensed_pre_cutover` + `migration_origin_grace` recognition |

## Gaps (must exist for Phase 20)

1. Atomic SaaS RPC/API: commercial grant consume + destination binding + source grace authz + idempotency key.
2. Sync `commercial_grants.quantity_consumed` on burn (end dual truth).
3. Installer/device-signed migration-authorization APIs (not dashboard-only).
4. Local apply engines for destination binding + source grace + Stage rebind.
5. Phase 21 readiness report signer (cutover still forbidden).
