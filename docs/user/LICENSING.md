# Licensing

## Concepts

| Term | Meaning |
|------|---------|
| License | Commercial entitlement object |
| Device | Bound host identity |
| Production Slot | One Production per License (enforced) |
| Support entitlement | Annual/legacy support capability |
| Update entitlement | Product update capability (typically via annual support) |
| Stage entitlement | Create/clone/refresh/rebuild Stages |
| Migration Token | Authorization for Soviez↔Soviez migration |

## Provider neutrality

```text
payment provider ≠ entitlement authority
```

Stripe (or future providers), admin grants, and complimentary grants all resolve through the same entitlement model.

## Runtime independence

Licensing/SaaS outages do **not** shut down ERP. Local backup, status, diagnostics, and recovery remain available.

See also [SUPPORT_AND_EXPIRY.md](SUPPORT_AND_EXPIRY.md).
