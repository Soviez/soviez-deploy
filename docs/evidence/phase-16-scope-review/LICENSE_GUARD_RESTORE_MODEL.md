# License Guard Restore Model — Phase 16 (Proposed)

## Non-negotiables

- Do **not** weaken License Guard.  
- Do **not** invent a new permanent license slot for restore candidates.  
- Do **not** bypass Guard for “emergency restore.”

## Same-host Production restore candidate

**Reuse Phase 15 temporary candidate identity contract:**

| Property | Value |
|----------|-------|
| Schema pattern | Align with `soviez.update-candidate-identity.v1` (or successor restore-specific schema versioned similarly) |
| Slot consuming | **false** |
| Independent production | **false** |
| Sellable | **false** |
| Guard bypass | **forbidden** |
| Bound to | operation_id, license_id, production_id, database_uuid, host, candidate container |
| TTL | temporary (`candidate_valid_until`) |

Restore candidate is temporary infrastructure for validation + switch — same spirit as update candidate.

## After successful switch

Live Production continues under the **existing** permanent License binding.  
Temporary candidate identity is invalidated/expired; no second permanent slot burned.

## Cross-host restore

Requires **migration / reactivation** flows (Phase 17+).  
Phase 16 must refuse cross-host restore rather than mint slots or weaken Guard.

## Restore-as-Stage

Stage License / entitlement gates apply independently.  
Do not reuse Production License as Stage entitlement.

## Failure cases

| Case | Behavior |
|------|----------|
| Guard rejects candidate | Fail closed; no switch |
| Root disables Guard module | Honest residual (same as Phase 15); not DRM claim |
| Wrong License on backup | Deny restore |
| Stale candidate TTL | Deny start/switch; cleanup |

## Explicit non-claims

License Guard is not a backup encryption system and does not replace destination encryption or archive integrity verification.
