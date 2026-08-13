# OPEN_ITEMS

| ID | Item | Class | Blocks |
|----|------|-------|--------|
| PP-01 | soviez-sh has no Git remote | OWNER_DECISION + BLOCKS_PUBLISH | push |
| PP-02 | soviez-sh missing `.gitignore` | BLOCKS_PUBLISH | first commit safety |
| PP-03 | Root secrets `keys.json`, `ticket.token`, `offline-package.json` must stay untracked | BLOCKS_PUBLISH | secret hygiene |
| PP-04 | ERP dirty tree includes unrelated CHANGELOG/venv — publish must be path-scoped | BLOCKS_MAIN_MERGE if careless | merge hygiene |
| PP-05 | SaaS UI vs backend bundling / Phase 11.5 visual freeze | OWNER_DECISION | commercial polish only |
| PP-06 | Create GitHub repo + initial commit strategy for soviez-sh | OWNER_DECISION | publish |
| PP-07 | OD-RELEASE-OFFHOST-BACKUP pending | OWNER_DECISION | commercial release only |
| PP-08 | Phase 11.5 visual acceptance deferred | OWNER_DECISION | commercial release only |
| PP-09 | Release Authorization NOT AUTHORIZED | OWNER_DECISION | all release classes |
| PP-10 | SaaS staging/sandbox for full live sim | BLOCKS_LIVE_SIMULATION | live E2E |
| PP-11 | Disposable VPS/DNS/Registry/License fixtures for live sim | BLOCKS_LIVE_SIMULATION | live E2E |
| PP-12 | Registry image availability for sim tags | BLOCKS_LIVE_SIMULATION | pull path |
| PP-13 | Live remote reachability/auth not re-probed this audit | NON_BLOCKING | ops |
| PP-14 | Evidence bulk vs summary publication preference | OWNER_DECISION / NON_BLOCKING | repo size |

Runtime defects currently open: **0** (certified).  
Documentation defects currently open: **0** (validator OK).  
Security blockers in code: **0** new; hygiene blockers for commit: PP-02/03.
