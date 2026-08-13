# Stage entitlement and retention

## Existing
One Stage DB `stage` per tenant; same MAC+UUID; domain mandatory; SSL with self-signed fallback; Safe Shield on drop; no Cloud entitlement; no 60-day clock.

## Planned
Stage License monthly → license_id bound; multiple stages; expiry blocks create/refresh only; 60-day retention independent of entitlement; warnings + Safe Shield auto-delete.
