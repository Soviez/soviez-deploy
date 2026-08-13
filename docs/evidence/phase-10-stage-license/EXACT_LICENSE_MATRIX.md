# EXACT_LICENSE_MATRIX — Phase 10

| Case | Expected |
|------|----------|
| License A entitlement | A allowed |
| License B (same account) | Denied (`STAGE_LICENSE_NOT_FOUND` / not covered) |
| Wrong account | `WRONG_ACCOUNT` |
| Missing license | `LICENSE_REQUIRED` / `LICENSE_NOT_FOUND` |
| Unbound grant | Not materialized (commercial upsert requires `target_license_id`) |
| Account-level fallback | Impossible (resolver requires `license_id`) |
| Device alone | Does not grant Stage |
| Annual Support alone | Does not grant Stage |
| IP-only target | Not accepted for Stage checkout |

DB cert: cross-license independence PASS.
