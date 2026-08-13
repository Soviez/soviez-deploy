# PORTAL_UX_MATRIX — Phase 10 Stage License

| Surface | Path | Behavior |
|---------|------|----------|
| Customer coverage card | Dashboard → Support tab → Stage Environments | License selector; coverage from `/api/stage-license/coverage` |
| Purchase flow | Support tab | Quote → `/api/checkout/stage-license` → Stripe |
| Admin entitlements | `/admin/stage-license` | List, grant form, revoke by idempotency key |
| Admin link | Add-ons tab | Link to Stage License Admin |

Required copy shown: exact license, unlimited commercial, existing stages unaffected, runtime later.
