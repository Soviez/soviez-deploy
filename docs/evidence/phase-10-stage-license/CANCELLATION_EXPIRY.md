# CANCELLATION_EXPIRY — Phase 10

| State | New Stage ops | Existing Stages |
|-------|---------------|-----------------|
| active | Allowed | Unaffected |
| canceled (before period end) | Allowed until `valid_until` | Unaffected |
| expired after period end | Denied | Unaffected |
| past_due | Denied | Unaffected |
| refunded / revoked / disputed | Denied | Unaffected |

Production ERP unaffected. No phone-home. No forced Stage stop/delete.
