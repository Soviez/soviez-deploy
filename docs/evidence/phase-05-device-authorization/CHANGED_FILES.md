# Changed files — Phase 5

## soviez-saas (working tree vs HEAD 2f2f13c — includes Phases 3–5 uncommitted)

```
 M package-lock.json
 M package.json
 M src/app/api/license/generate/route.ts
 M src/components/dashboard/dashboard-page-client.tsx
 M src/lib/admin-provisioning.ts
 M src/lib/fulfill-checkout-session.ts
 M src/lib/stripe-dispute-pipeline.ts
 M src/lib/stripe-refund-pipeline.ts
 M src/lib/stripe-subscription-pipeline.ts
 M src/lib/supabase/middleware.ts
 M src/types/database.ts
?? docs/
?? scripts/mock-server-only.cjs
?? src/app/api/installer-auth/
?? src/app/dashboard/devices/
?? src/app/installer/
?? src/components/dashboard/devices-manage-client.tsx
?? src/components/installer/
?? src/lib/commercial/
?? src/lib/device-auth/
?? src/lib/entitlements/
?? supabase/migrations/078_provider_neutral_commercial_ledger.sql
?? supabase/migrations/079_capability_entitlement_foundation.sql
?? supabase/migrations/080_materialize_capability_result_contract.sql
?? supabase/migrations/081_device_authorization_foundation.sql
```

## Phase 5 primary paths

- supabase/migrations/081_device_authorization_foundation.sql
- src/lib/device-auth/**
- src/app/api/installer-auth/device/**
- src/app/installer/authorize/page.tsx
- src/app/dashboard/devices/page.tsx
- src/components/installer/installer-authorize-client.tsx
- src/components/dashboard/devices-manage-client.tsx
- src/components/dashboard/dashboard-page-client.tsx (Devices link)
- src/lib/supabase/middleware.ts (/installer protected)
- src/types/database.ts (device tables)
- package.json (test:phase5*)
- docs/device-authorization.md
