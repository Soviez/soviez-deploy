# OWNER_REVIEW_ROUND_2.md

## History

1. Round 1 preview: parallel fixture / top-nav → **REJECTED**
2. Design correction still fixture-centered → **REJECTED** (not the real SaaS product)
3. Round 2 (this): real SaaS app + demo Supabase + Stripe test → **PARTIAL** pending DB migrations + Playwright

## Owner checklist

- [ ] Login as customer → real Client Dashboard sidebar appears
- [ ] Unrelated sidebar pages still load
- [ ] License cards show three statuses + rename
- [ ] Open Instance detail tabs
- [ ] Manual activation key still available
- [ ] Automatic activation Device panel readable
- [ ] Migration tokens / Migrate Instance still on Overview card
- [ ] Annual Support quote + Stripe test checkout (blocked until demo migrations applied)
- [ ] Stage License quote + checkout (blocked until demo migrations applied)
- [ ] Admin real shell login
- [ ] Confirm fixture `?preview=1` is **not** the acceptance path

## Approval gate

Only after explicit owner approval:

`PASS — PHASE 11.5 SAAS UI/UX/PX CLOSURE COMPLETE` and progress **65%**.

Until then progress remains **60%**. Phase 12 unauthorized.
