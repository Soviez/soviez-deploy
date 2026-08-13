# DESTINATION_ACTIVATION_MODEL.md

## Status name (recommended)

**`production_licensed_pre_cutover`**

Meaning: destination holds the permanent Production License binding and may run ERP in Production mode **internally** for validation — **not** customer traffic owner.

Avoid ambiguous “Production activated” without qualifier.

## Required properties

- Permanent Production binding (License, device, environment, DB UUID, image digest, migrated source identity)
- License Guard active; permanent slot count correct (no extra slot)
- No public Production route; Production domain not attached
- Customer traffic disabled
- Mail / payments / webhooks / business cron neutralized (OD)
- Internal technical validation + optional controlled internal login (OD)
- Phase 19 staging identity superseded/closed for commercial purposes after commit apply

## Verification checklist

See FINAL_REPORT / TEST_PLAN — LG bind, slot count, health, filestore, modules, public_route=false, traffic_owner=source.
