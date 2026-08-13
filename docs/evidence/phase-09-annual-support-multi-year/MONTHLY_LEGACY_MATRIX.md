# MONTHLY_LEGACY_MATRIX — Phase 9

## New sales block

| Endpoint | interval | HTTP | code |
|----------|----------|------|------|
| `/api/checkout/support-subscription` | month | 403 | MONTHLY_NEW_SALES_DISABLED |
| `/api/checkout/support-subscription` | year | 200* | — |
| `/api/checkout/support/annual` | prepaid | 200* | — |

*Requires auth + valid license + SLA acceptance

## Settings default

`support_commercial_settings.monthly_new_sales_enabled = false`

Admin may set `true` via PATCH settings — **not recommended** without owner decision (D008).

## Legacy monthly subscriber

Certification fixture:

```sql
INSERT INTO user_addons (..., addon_slug='technical-support-monthly', billing_interval='month', ...)
```

| Check | Result |
|-------|--------|
| `support_resolve_annual_coverage` allowed | false |
| Portal `readAnnualCoverageForLicense` | status=legacy_monthly |
| includesProductUpdates | false |
| denialCode | MONTHLY_DOES_NOT_INCLUDE_UPDATES |
| active product_updates grants | 0 |

## Legacy recurring annual

Detected when:

- `user_addons.addon_slug = technical-support-annual`
- `current_period_end > now()`
- `stripe_subscription_id` does NOT start with `prepaid-` or `admin-`

Portal: status=active, legacyRecurring=true, includesProductUpdates=true.

## Renewal paths for legacy monthly

Existing Stripe subscription webhooks continue to renew monthly rows. Customer cannot **start** new monthly via portal checkout.

Migration policy (D008) remains **requires owner decision**.
