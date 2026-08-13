# FULL_PLATFORM_PREVIEW.md

## Topology

| Layer | Value |
|-------|--------|
| App | Real `soviez-saas` Next.js 15 (`next dev`) |
| Mode | `SOVIEZ_PREVIEW_MODE` **unset** → `previewMode: false` |
| URL | http://127.0.0.1:3011/login |
| Auth | Real Supabase Auth (`/api/auth/login`) |
| Data | Isolated demo Supabase project `bzkokygmagcseasuiiqs` |
| Payments | Stripe **test** keys from `.env.local` (`sk_test_…`) |
| PID/log | `/tmp/soviez-phase115-preview.pid`, `/tmp/soviez-phase115-preview.log` |

## Commands

```bash
cd /Volumes/PortableSSD/soviez-project/soviez-saas
npm run seed:phase11.5-demo   # optional refresh of demo users/licenses
bash scripts/preview-start.sh
bash scripts/preview-stop.sh
```

## Credentials (demo only)

| Role | Email | Password |
|------|-------|----------|
| Customer | customer.demo@soviez.local | Demo-Customer-11.5! |
| Admin | admin@admin.com | 010203@## |

## Seeded licenses

- Main Production — `1a8dd6a7-e6ec-4742-ac48-6d81ba9b9f06`
- Legacy Site — `978c8ef6-ec40-49c8-b526-422618d6e8a9`

## Health

`GET /api/preview/status` → `{ "previewMode": false, "message": "Production/app mode" }`
