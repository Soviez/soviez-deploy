# REAL_SAAS_INTEGRATION_CORRECTION.md

**Phase:** 11.5  
**Date:** 2026-07-30  
**Verdict contribution:** PARTIAL (see FINAL_REPORT)

## Owner rejection recorded

The first Phase 11.5 preview was **REJECTED BY OWNER** because it shipped a parallel fixture UI (top-nav / later fixture sidebar) instead of the live SaaS product.

## Correction direction (this pass)

Integrate Phase 3–11 capabilities into the **real** `soviez-saas` application:

| Area | Action |
|------|--------|
| Dashboard entry | `src/app/dashboard/page.tsx` always renders `DashboardPageClient` (real shell) |
| Fixture acceptance | `PreviewDashboardClient` marked **retired** from owner acceptance |
| Preview start | `scripts/preview-start.sh` runs Next with `.env.local`, **unsets** `SOVIEZ_PREVIEW_MODE` |
| Login | Preview cookie auth only if `?preview=1` **and** `SOVIEZ_PREVIEW_MODE=1` |
| Instance UX | Real route `/dashboard/instances/[id]` + enhanced `LicenseCard` |
| Parallel routes | `/dashboard/servers|stages|operations|licenses|devices` redirect → `/dashboard` |
| Demo seed | `scripts/seed-phase115-demo-customer.ts` seeds demo Supabase customer + licenses |

## Explicitly not accepted as product

- `/api/preview/*` fixture auth/data (available only when `SOVIEZ_PREVIEW_MODE=1`)
- `PreviewDashboardClient` expand-in-place Instance panel
- Fixture emails `*.soviez.preview`

## Remaining blockers (PARTIAL)

1. Demo Supabase project is missing Phase 9/10 tables (`support_commercial_settings`, Stage License tables). Direct `DATABASE_URL` host is IPv6-only / unreachable from this workstation, so migrations 084–086 could not be applied in this pass.
2. Playwright is not installed; journeys used fetch harness + manual API smoke (owner requires real browser automation for full acceptance).
3. `system_settings` decrypt failures on the demo project fall back to in-memory defaults (Stripe test keys still load from `.env.local`).

## Next action

`WAIT FOR OWNER REVIEW OF THE REAL COMPLETE PLATFORM — DO NOT START PHASE 12`
