# FULL_FUNCTIONAL_REGRESSION.md

## Commands

| Command | Result |
|---------|--------|
| `npm run lint` | PASS (warnings only) |
| `npm run typecheck` | PASS |
| `npm run test:phase9` | PASS 10/10 |
| `npm run test:phase10` | PASS 7/7 |
| `npm run test:phase11.5` | PASS 27/27 |
| `npm run test:phase11.5-browser` | PASS 7/7 |
| `npx playwright test --project=chromium-desktop` | PASS 12/12 |
| `npx playwright test --project=chromium-mobile` (A/B/D/E/F/G/I) | PASS 7/7 |
| `npm run test:phase5` | PASS 14 |
| `npm run test:phase6` | PASS 6 |
| `npm run test:phase7` | PASS 9 |
| `npm run test:phase10.5` | PASS 12 |
| `npm run test:commercial` | PASS 11 |
| `npm run test:entitlements` | PASS 24 |
| `npm run build` | PASS |
| `scripts/phase115-functional-freeze.ts` | EG/SA PASS; price-book debt documented |

## Security isolation (freeze script)

- Unauth Annual quote → 401  
- Foreign License → 404 `LICENSE_NOT_FOUND`  
- Monthly new sales → 403 `MONTHLY_NEW_SALES_DISABLED`  
- Customer cannot access admin (Playwright)  

## Preview

Restarted after build; `http://127.0.0.1:3011/login` → 200; `previewMode:false`
