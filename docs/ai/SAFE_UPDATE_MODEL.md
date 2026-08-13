# Safe Update Model (Phase 15)

## Objective
Exact-target Production update with Annual `product_updates` entitlement, digest-pinned signed releases, isolated candidate validation, controlled switch, and mandatory rollback — integrated with Phase 14 unified operations.

## Non-goals
Phase 16 Backup/Restore product; Phase 17 migration landing/DNS; Phase 23 full offline product; SaaS UI changes; Annual Support pricing changes; weakening License Guard.

## Exact target
`--update <production-environment-id>` mandatory. Refuse empty, `all`, `*`, Stage IDs, ambiguous matches, deleted/archived. No account-wide or wildcard defaults.

## Entitlement gate
Capability `product_updates` via provider-neutral resolver. Allow Annual / multi-year / explicit admin grants / valid offline entitlement. Deny monthly technical support, unbound grants, wrong license/account, revoked/expired.

## Release / digest
Signed manifest + immutable digest. No `latest`. Arch + ERP major compatibility. Downgrade denied by default.

## Preflight / capacity
PASS / WARNING_REQUIRES_CONFIRMATION / BLOCKED. Capacity from measured DB/filestore/image + documented 25% safety margin.

## Backup / candidate / switch / rollback
Recovery set outside candidate; isolated DB/filestore/container/network; neutralized outbound; no Production license slot burn; switch only after validation + confirm; 24h safety window; honest post-switch write boundary.

## License Guard (temporary candidate)
Installer contract `soviez.update-candidate-identity.v1` binds candidate to authoritative Production/license/DB UUID/host. No Guard bypass env. No second slot. Guard has no first-class temp-candidate mode — Full Root residual disclosed. See `docs/dev/UPDATE_LICENSE_GUARD_CANDIDATE_PROTOCOL.md`.

## Image retention / cleanup
Retain current + rollback; 24h window; classify/reference/TOCTOU; no broad prune; op type `update_image_cleanup`; `production_update` supersedes scheduled cleanup. See `docs/dev/SOVIEZ_IMAGE_RETENTION_AND_CLEANUP_PROTOCOL.md`.

## Reboot / recovery
Update checkpoints reconcile after host/VM restart; `switching` / `rollback_running` → `UPDATE_RECOVERY_REQUIRED` (no blind replay).

## Sovereignty
No business data to SaaS. Entitlement checked only on explicit update. Support expiry never stops installed ERP.

## Offline
Signed package path (not full Phase 23). Zero network in offline mode after import.

## Status
**PASS** — final certification closure 2026-07-31 (`docs/evidence/phase-15-final-certification-closure/`). Progress **78%**.

## Future
Phase 17 migration flows remain unauthorized.
