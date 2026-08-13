# ADMIN_OFFLINE_FIXTURES — Phase 10

- Route: `POST /api/admin/stage-license`
- Sources: `manual_offline` | `admin_grant` | `complimentary`
- Fields: accountId, licenseId, reason, idempotencyKey, optional months/amount/currency
- No Stripe payment fabricated in commercial ledger (`no_stripe_payment` metadata)
- Revoke: `{ action: "revoke", idempotencyKey, reason }`
- Actor + reason required; audit actions `stage_license.grant` / `stage_license.revoke`
- DB cert covers upsert + revoke via RPC
