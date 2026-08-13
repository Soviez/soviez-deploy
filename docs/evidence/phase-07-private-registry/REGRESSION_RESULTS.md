# Regression results — Phase 7

**Date:** 2026-07-30  
**Verdict:** All regressions **PASS**

## Phase 3–4 commercial closure

| Suite | Result |
|-------|--------|
| `test:commercial-closure` (unit early) | **24 pass** |
| `test:commercial-closure` (db) | **13 pass** |

## Phase 5 device authorization

| Suite | Result |
|-------|--------|
| `test:phase5` | **14 pass** |
| `test:phase5-db` | **8 pass** |

## Phase 6 license slot reservation

| Suite | Result |
|-------|--------|
| `test:phase6` | **6 pass** |
| `test:phase6-db` | **6 pass** |

## Static analysis

| Check | Result |
|-------|--------|
| ESLint | **No warnings** |
| TypeScript (`soviez-saas`) | **pass** |
| `npx next build` | **pass** (registry routes present) |
| Gateway typecheck | **pass** |
| Gateway build | **pass** |

## Explicitly not run

| Action | Reason |
|--------|--------|
| Live `apply-migrations` against production Supabase | ENOTFOUND — correctly avoided |
| Live Hub private cutover | Out of scope |
| Installer runtime changes | Out of scope |

## Conclusion

Phase 7 additions are additive. No regression in Phases 3–6 foundations.
