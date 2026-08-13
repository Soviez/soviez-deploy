# SCHEMA_AND_RLS — Phase 10 Stage License

**Migration:** `085_stage_license_monthly.sql`

## Tables

- `stage_license_settings` (singleton)
- `stage_license_entitlements`
- `stage_license_events`
- `stage_license_quotes`

## Purchase column

- `purchases.stage_license_quote_id`

## RPCs

- `stage_license_resolve`
- `stage_license_evaluate_operation`
- `stage_license_upsert_entitlement`
- `stage_license_mark_status`

## Index

- `stage_license_one_open_per_license_idx` — partial unique on open statuses
