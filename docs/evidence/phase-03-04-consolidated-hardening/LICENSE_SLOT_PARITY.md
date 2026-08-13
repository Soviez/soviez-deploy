# License Slot parity

Compared in shared isolated DB:

- `get_available_license_slots` (legacy SoT)
- `get_neutral_available_license_slots` (shadow)
- capability resolve `license_slot` available_quantity

| Scenario | Match |
|----------|-------|
| Stripe-paid available | PASS |
| Admin-granted | PASS |
| Consumed | PASS |
| Refunded grant revoked | PASS |
| Pending/failed excluded | PASS |
| Duplicate dual-write | PASS (single tx/grant) |

**Cutover:** none.
