# SAAS_PUBLICATION_SCOPE

Remote: `https://github.com/agharaafat/sovize.git`  
Branch target: `main` (deploy via `staging` first recommended)

## Requires publish? YES

### Schema (REQUIRED)
Migrations **078–090**:
- 078 provider-neutral commercial ledger
- 079 capability entitlement foundation
- 080 materialize capability result contract
- 081 device authorization foundation
- 082 license slot reservation foundation
- 083 private registry pull foundation
- 084 annual support multi-year
- 085 stage license monthly
- 086 stage operation authorization
- 087 migration authorization atomic
- 088 migration traffic owner
- 089 migration source archived
- 090 offline update bundles

### Runtime/API (REQUIRED)
- `src/lib/{device-auth,entitlements,registry,slot-reservation,stage-license,stage-operation,migration-*,offline-bundle,commercial,annual-support}/**`
- `src/app/api/installer*/**`, stage-license, support, related checkout routes
- `src/types/database.ts`, `scripts/apply-migrations.ts`, package manifests as needed

### Admin/UI surfaces
Lifecycle admin/dashboard pages for devices/servers/stages/reservations/operations are **in-cycle for live simulation** but Phase 11.5 visual acceptance is deferred — publish **functional** UI required for ops; do not treat visual polish as publish blocker.

### Exclude
`.env*`, playwright browsers/reports, disposable proof scratch if sensitive.

### Unrelated
Pure marketing/landing churn without contract change — review before bundling.
