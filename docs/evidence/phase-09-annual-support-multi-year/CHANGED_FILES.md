# CHANGED_FILES — Phase 9

## Created (soviez-saas)

### Migration

- `supabase/migrations/084_annual_support_multi_year.sql`

### Library

- `src/lib/annual-support/index.ts`
- `src/lib/annual-support/codes.ts`
- `src/lib/annual-support/pricing.ts`
- `src/lib/annual-support/pricing.test.ts`
- `src/lib/annual-support/quote.ts`
- `src/lib/annual-support/coverage.ts`
- `src/lib/annual-support/checkout.ts`
- `src/lib/annual-support/admin-grant.ts`
- `src/lib/annual-support/routes.contract.test.ts`
- `src/lib/annual-support/e2e/harness.ts`
- `src/lib/annual-support/e2e/certification.test.ts`

### API routes

- `src/app/api/support/annual/quote/route.ts`
- `src/app/api/support/annual/coverage/route.ts`
- `src/app/api/checkout/support/annual/route.ts`
- `src/app/api/admin/support/term-discounts/route.ts`
- `src/app/api/admin/support/annual-grant/route.ts`

### Admin UI

- `src/app/admin/support-annual/page.tsx` (route)
- `src/components/admin/support-annual-admin-panel.tsx`

## Modified (soviez-saas — Phase 9 touchpoints)

- `package.json` — `test:phase9`, `test:phase9-db`, `test:phase9-all`
- `src/types/database.ts` — 084 schema types
- `src/lib/fulfill-checkout-session.ts` — prepaid annual fulfillment hook
- `src/lib/stripe-refund-pipeline.ts` — coverage reverse + partial review
- `src/lib/stripe-dispute-pipeline.ts` — coverage event integration
- `src/lib/admin-audit-log.ts` — support admin audit actions
- `src/app/api/checkout/support-subscription/route.ts` — monthly block
- `src/components/support/support-subscription-landing.tsx` — annual UX
- `src/components/checkout/support-subscription-selector.tsx` — annual flow
- `src/components/dashboard/support-tab.tsx` — coverage display
- `src/app/support/page.tsx` — support landing

## Created (soviez-sh — governance/docs)

- `docs/ai/ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`
- `docs/dev/ANNUAL_SUPPORT_PROTOCOL.md`
- `docs/user/SUPPORT_EXPIRATION.md`
- `docs/evidence/phase-09-annual-support-multi-year/**`

## Updated (soviez-sh)

- `PROJECT_STATE.md`
- `docs/ai/CURRENT_STATE.md`
- `docs/ai/DECISION_LOG.md`
- `docs/ai/MASTER_IMPLEMENTATION_PLAN.md`
- `docs/ai/COMMERCIAL_ENTITLEMENT_MODEL.md`
- `docs/ai/PAYMENT_PROVIDER_ABSTRACTION.md`
- `docs/ai/CAPABILITY_AND_ENTITLEMENT_MODEL.md`
- `docs/ai/SOVEREIGNTY_FIRST_CONSTITUTION.md`
- `docs/dev/PAYMENT_AND_GRANT_ABSTRACTION.md`
- `docs/dev/ENTITLEMENT_API_CONTRACT.md`
- `docs/user/ANNUAL_SUPPORT.md`
- `docs/user/PRIVACY_AND_SOVEREIGNTY.md`

## Not committed

Working tree dirty; no commit or push per phase instructions.
