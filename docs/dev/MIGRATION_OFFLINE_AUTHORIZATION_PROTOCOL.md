# Migration Offline Authorization Protocol

## Honesty boundary

Distributed offline exactly-once commercial consume without ledger reconciliation is **not claimable**. Phase 20 does not invent local tokens.

## Model

1. **Connected commit first** — token consumed via `commit_migration_authorization`; receipt embedded in offline package.
2. **Export** — `soviez_migration_authorization_export` wraps committed authorization in `soviez.migration_authorization_offline_package.v1`.
3. **Package constraints** — short expiry (default 1h), `no_private_keys=true`, public signature over authorization body.
4. **Import** — verify expiry, committed status, signature; register replay in ledger `offline_replay` table.
5. **Local apply** — binding + grace applied from package; SaaS reconciliation mandatory when connected.

## Replay protection

`offline-register --package-id` — duplicate package → `MIGRATION_AUTHORIZATION_REPLAY_DENIED`.

## Limits

- Package requires `transaction_status=committed` (no offline-first consume).
- Expired package → import denied.
- Conflicting connected consumption → fail closed.

## Modules

- `src/migration/authorization/offline.sh`
- Ledger: `register_offline` command in `ledger.py`

## Non-goals

- Local arbitrary token creation
- Unlimited offline dual-use
- Skipping SaaS reconciliation on reconnect
