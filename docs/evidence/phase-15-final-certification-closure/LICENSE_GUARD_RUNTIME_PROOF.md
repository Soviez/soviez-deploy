# License Guard Runtime Proof

## Evidence files (candidate runtime)
- `license_guard_identity.json` — v1 identity contract
- `license_guard_proof.json` — runtime presence checks

## Checks performed
- `local_license_guard` included in `-i/-u` module list
- `license_tools.so` / Guard module present in image path
- Forbidden bypass env vars refused (`SOVIEZ_DISABLE_LICENSE`, `SOVIEZ_SKIP_LICENSE_GUARD`, …)
- Slot ledger snapshot before/after: **no slot burn**
- `license_slot_consumed=false` in identity JSON

## Result
PASS — installer contract + runtime proof without Guard bypass.
