# CAPABILITY_MATRIX — Phase 9

## By coverage source

| Source | technical_support | product_updates | Strict resolver | Legacy support RPC |
|--------|-------------------|-----------------|-----------------|-------------------|
| Prepaid annual (active) | ✅ | ✅ (license-bound) | via commercial_grants | compat mirror |
| Legacy recurring annual | ✅ | ✅ | via user_addons + materialize | ✅ |
| Legacy monthly (active) | ✅ | ❌ fail closed | no grant | ✅ |
| Expired / none | ❌ | ❌ | denied | ❌ |
| requires_admin_review | ✅ until admin acts | ✅ until admin acts | unchanged | — |

## Portal coverage API mapping

| status | includesTechnicalSupport | includesProductUpdates |
|--------|--------------------------|------------------------|
| active | true | true |
| legacy_monthly | true | false |
| expired | false | false |
| not_covered | false | false |

## Commercial ledger sync

`fulfillPrepaidAnnualSupport` → `syncCommercialLedgerForPurchase`:

- Creates/updates `commercial_grants` for purchased addon
- Materialization expands `product_updates` when annual + license bound (Phase 4 rule)

## Future `--update` gate (not this phase)

Installer will call entitlement/coverage API with exact license_id:

- Allowed: active prepaid or legacy annual with product_updates
- Denied: `COVERAGE_EXPIRED`, `MONTHLY_DOES_NOT_INCLUDE_UPDATES`

## Denial codes (capability-relevant)

```
COVERAGE_EXPIRED
MONTHLY_DOES_NOT_INCLUDE_UPDATES
UNBOUND_LEGACY_GRANT
PARTIAL_REFUND_REQUIRES_REVIEW
LICENSE_REQUIRED
```
