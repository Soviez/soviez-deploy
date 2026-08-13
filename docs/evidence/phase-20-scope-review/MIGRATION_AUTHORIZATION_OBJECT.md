# MIGRATION_AUTHORIZATION_OBJECT.md

Signed canonical object (no private secrets), schema e.g. `soviez.migration_authorization.v1`:

- schema version, authorization ID, operation ID, idempotency key
- account ID, License ID
- source Production/environment/device fingerprint, DB UUID, image digest
- destination environment/device fingerprint, DB UUID, image digest
- migration-pair ID; Phase 18 routing-plan ID; Phase 19 transfer-manifest ID + staging ID + readiness status
- Migration Token entitlement/grant ID; grant source; qty before/after; consumed timestamp
- source binding before; destination binding after; source grace-state ID
- selected Stage IDs + rebind results
- transaction status; commit timestamp; expiry; signer; public signature
- rollback/compensation state
- `phase21_allowed=false` until separate readiness
- `production_dns_changed=false`; `traffic_cutover_started=false`

Pre-commit validity recommended: **30 minutes** (OD).
