# REAL_PLATFORM_OWNER_PREVIEW.md — Round 4

## Topology

- App: real `soviez-saas` Next.js (fixture/`SOVIEZ_PREVIEW_MODE` **off**)
- **Browser URL:** http://127.0.0.1:3011/login (also http://localhost:3011/login)
- Do **not** open `http://0.0.0.0:3011` in the browser (cookie / `randomUUID` issues)
- Port: **3011** (process may bind `0.0.0.0` internally)
- Supabase: isolated demo `bzkokygmagcseasuiiqs`
- Stripe: test mode
- Basket/checkout: real routes + Stripe Checkout
- Round 4: approved Instance Support UI + UUID/idempotency fix live in this process

## Credentials (demo only)

| Role | Email | Password |
|------|-------|----------|
| Customer | customer.demo@soviez.local | Demo-Customer-11.5! |
| Admin | admin@admin.com | 010203@## |

## Commands

```bash
cd /Volumes/PortableSSD/soviez-project/soviez-saas
npm run preview:start   # restart
npm run preview:stop    # stop
```

PID/log defaults: `/tmp/soviez-phase115-preview.pid`, `/tmp/soviez-phase115-preview.log`

## Health (verified Round 4)

- `/api/preview/status` → `previewMode: false`
- `/login` → HTTP 200

## Shell preservation

Original dashboard header, left sidebar, unrelated pages preserved. Instance Details Support & Updates matches approved design inside the real shell.
