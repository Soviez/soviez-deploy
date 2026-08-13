# License Guard Candidate Model

## Contract
Installer writes `license_guard_identity.json` with schema **`soviez.update-candidate-identity.v1`**.

## Properties
| Property | Value |
|----------|-------|
| Slot consuming | false |
| Independent production | false |
| Sellable | false |
| Guard bypass | false (forbidden) |
| Bound to | operation_id, license_id, production_id, database_uuid, host, candidate container |
| TTL | temporary (`candidate_valid_until`) |

## Explicit non-claims
- License Guard module has **no** first-class temporary-candidate mode.
- Full Root can still replace/disable Guard (honest residual; not DRM).
- No second permanent license slot is reserved or burned for the candidate.
