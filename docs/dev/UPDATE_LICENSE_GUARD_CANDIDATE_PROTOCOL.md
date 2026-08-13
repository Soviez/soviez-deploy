# Update License Guard Candidate Protocol

**Phase:** 15 final certification  
**Schema:** `soviez.update-candidate-identity.v1`  
**Module:** `src/update/license_guard_candidate.sh`

## Purpose

Allow an isolated update candidate to run ERP upgrade validation on the same host/hardware matrix as Production **without**:
- burning a second permanent License Slot
- becoming an independent Production
- disabling or bypassing License Guard

## Installer contract

Write `$candidate/runtime/license_guard_identity.json` with:

| Field | Rule |
|-------|------|
| `schema` | `soviez.update-candidate-identity.v1` |
| `authoritative_*` | Exact Production license_id / production_id / database_uuid |
| `candidate_container_identity` / network | Per-op disposable identities |
| `license_slot_consumed` | always `false` |
| `independent_production` | `false` |
| `non_sellable` / `non_slot_consuming` | `true` |
| `guard_bypass` / `guard_code_disabled` / `fake_activation` | `false` |
| `candidate_valid_until` | short TTL (default 6h) |

## Runtime proof

- Include `local_license_guard` in candidate `-i/-u`
- Record `license_guard_proof.json` (module / `license_tools.so` presence)
- Snapshot slot ledger before/after; assert no burn
- Refuse bypass env vars (`SOVIEZ_DISABLE_LICENSE`, `SOVIEZ_SKIP_LICENSE_GUARD`, …)

## Honest Root boundary

License Guard has **no** first-class temporary-candidate mode. Full Root can replace the Guard binary or disable enforcement. This residual is accepted and disclosed — not DRM.

## Cleanup

On candidate teardown, mark identity `cleanup_state` terminal; never promote candidate into a permanent slot.
