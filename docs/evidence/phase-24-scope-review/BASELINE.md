# BASELINE.md — Phase 24 Scope Review

## Certified state (do not change)

```text
Phase 16–22 = PASS
Phase 23 = PASS — SIGNED OFFLINE UPDATE BUNDLES, AIR-GAPPED DELIVERY, AND ENTITLEMENT-CONTROLLED APPLICATION COMPLETE
Progress = 99%
Installer = 0.23.0-phase23
SHA256 = b5267997825f995df7e5a1a137d1b5d8403971f278e8ad592ba90c88a84368bf
Phase 11.5 = FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED
Phase 24 implementation = NOT AUTHORIZED
Phase 25+ = UNAUTHORIZED
```

## Repositories

| Path | Role |
|------|------|
| `/Volumes/PortableSSD/soviez-project/soviez-sh` | Primary |
| `/Volumes/PortableSSD/soviez-project/soviez-saas` | Reference (frozen UI) |
| `/Volumes/PortableSSD/soviez-project/Soviez ERP` | Reference |
| `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh` | Legacy read-only |

## Dirty-state preservation

Existing Phase 23 dirty tree and certification evidence **must remain**. This review adds docs only under `docs/evidence/phase-24-scope-review/` and updates allowed state docs.

## Constraints for this mission

- No runtime/`dist`/CLI changes
- No progress change
- No installer regeneration
- No live systems
- No commit/push/merge/tag/deploy/publish/release
