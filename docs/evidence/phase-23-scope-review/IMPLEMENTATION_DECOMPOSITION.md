# IMPLEMENTATION_DECOMPOSITION

Proposed (not implemented):

```
src/offline_bundle/          # codes, model, manifest, authorization, signing, trust, targeting, compatibility, expiry, replay, import, inspect, staging, receipt, reconcile, engine
src/offline_bundle/export/   # entitlement, release, registry, images, addons, migrations, package, sign, verify, storage, report
src/offline_update/          # preflight, backup, candidate, image_import, addons, migrations, validate, switch, rollback, recover, result, engine
src/offline_trust/           # roots, rotation, revocation, clock, verify
src/offline_reconciliation/  # export, import, verify, conflict, report, engine
src/commands/                # offline_bundle.sh, offline_update.sh, offline_reconciliation.sh
```

Thin orchestration must call Phase 15 update and Phase 16 backup APIs.
