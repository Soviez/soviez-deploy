# AUTOMATIC_ACTIVATION_FULL_E2E.md

## Seeded Device states (demo artificial IDs)

| Device | License | Status | UX |
|--------|---------|--------|-----|
| HQ Production | Main Production | active | Connected |
| Warehouse Server | Warehouse | disabled | Needs Action / reauth |
| Revoked Lab Box | Main Production | revoked | Needs Action when no active Device |

## Browser Journey E

Instance → Activation → Automatic Activation + Server Connection tab show fingerprint / Revoke / Reauthorize / Connected surfaces. Manual Activation remains on the same tab (coexistence proven Journey D).

## State transitions (demo DB + instance-summary)

| Action on HQ Production | instance-summary Soviez.sh |
|-------------------------|----------------------------|
| status → revoked (with other revoked Device present) | Needs Action |
| status → reauthorization_required | Needs Action |
| status → active | Connected to HQ Production |

API layer: `cli_devices` persistence + `/api/licenses/[id]/instance-summary` mapping. No browser-only fake state.

## Manual regression

Journey D: Manual Activation key/copy/instructions still present; Automatic does not replace Manual.
