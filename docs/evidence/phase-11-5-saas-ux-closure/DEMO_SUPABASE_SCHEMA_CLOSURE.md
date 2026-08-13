# DEMO_SUPABASE_SCHEMA_CLOSURE.md

**Date:** 2026-07-30  
**Target (fail-closed):** `bzkokygmagcseasuiiqs.supabase.co`  
**Connection method:** Supabase session pooler `aws-0-eu-central-1.pooler.supabase.com:5432` as `postgres.<ref>` (direct `db.*` host is IPv6-only / unreachable from this workstation).

## Applied migrations (checksums)

| File | Status | SHA-256 |
|------|--------|---------|
| 078_provider_neutral_commercial_ledger.sql | APPLIED | 2773d22d8ba45a70263faa16dd92c910ca354ad4c292dbe7c523554aa649b65e |
| 079_capability_entitlement_foundation.sql | APPLIED | 6eb7fc0d7221db570090e328fee9f4d1327af5e7de34e6bbb1f659effef4d62a |
| 080_materialize_capability_result_contract.sql | APPLIED | 1098ee757e564f4c9396d2d8b5ba332ac5b8fccfb257f912282a9b3043b506c9 |
| 081_device_authorization_foundation.sql | APPLIED | b4d959bfe43babbab3e0e0b3b0f65b45865cf6c14d0e7ebe1c014d9a8afd5a61 |
| 082_license_slot_reservation_foundation.sql | APPLIED | 197607d630e4be018d38063d7a35c27abe4672f85a45941f9f4cf7eb0cfcd44b |
| 083_private_registry_pull_foundation.sql | APPLIED | 60dc982a2fb0fe92fdf3ac7d27c1ab31a6142465b3ed0f86878dba3bf5e4871c |
| 084_annual_support_multi_year.sql | APPLIED | 3409e753e57f5bacdf1f501a6cdad2e16560612edd54c4f09844b39a2381af20 |
| 085_stage_license_monthly.sql | APPLIED | 5bb9616f1eb6f16fe64cf665996de5c43ba1254d691ca4666ea7175739137ff1 |
| 086_stage_operation_authorization.sql | APPLIED | 5ccef204353770f868964fac8c8cc4c7d35b0b5f185c44c96ce680b3de982018 |

Tracked in `public._migration_history` with checksum column.

## Demo-only constraint fix

`purchases_billing_type_check` extended to allow `prepaid_term` (required by Annual Support checkout; TypeScript `BillingType` already included it; migration 084 added column but not constraint expansion). Recorded as `084b_demo_prepaid_billing_type.sql` in history.

## Verification

- `support_commercial_settings` row id=1: `monthly_new_sales_enabled=false`, `annual_prepaid_enabled=true`
- `stage_license_settings` row id=1: `product_enabled=true`
- PostgREST schema reload via `NOTIFY pgrst, 'reload schema'`
- Live API: Annual Support + Stage License quotes succeed against demo project

## Tooling

- `scripts/apply-demo-phase9-11-migrations.ts` — fail-closed to demo ref only
