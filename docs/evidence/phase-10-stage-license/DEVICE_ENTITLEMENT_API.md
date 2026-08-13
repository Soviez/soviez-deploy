# DEVICE_ENTITLEMENT_API — Phase 10

Route: `POST /api/installer/entitlements/stage/check`

- Auth: Phase 5 Device PoP via `requireDeviceSignedRequest`
- Account derived from Device — client `account_id` never trusted
- Body: `license_id`, `operation`
- No browser login when Device credential valid
- No Stage creation / commercial mutation side effects
- Revoked Device → deny (`DEVICE_REVOKED` / unauthorized)
- Wrong license ownership → `WRONG_LICENSE`
- Route contract tests import/export PASS

Installer `soviez.sh --stage` **not wired** in this phase.
