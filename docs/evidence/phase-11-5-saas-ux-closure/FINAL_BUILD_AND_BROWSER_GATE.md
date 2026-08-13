# FINAL_BUILD_AND_BROWSER_GATE.md — Round 4

## Commands

| Command | Result |
|---------|--------|
| `npm run lint` | PASS (warnings only) |
| `npm run typecheck` | PASS |
| `npm run test:phase11.5` | PASS **27/27** |
| `npx playwright test --project=chromium-desktop` | PASS **12/12** |
| `npx playwright test --project=chromium-mobile` (A/B/G) | PASS **3/3** |
| `npm run build` | PASS |

## Notes

- `apply-migrations.ts` fail-closed session-pooler rewrite only for demo ref `bzkokygmagcseasuiiqs` when `db.*.supabase.co` is unreachable (build gate).
- Preview browser URL: **http://127.0.0.1:3011** (not `0.0.0.0`).
- Preview kept running after build/Playwright (`previewMode: false`, `/login` HTTP 200).
