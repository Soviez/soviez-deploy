# MAIN_INTEGRATION_STRATEGY

| Repo | Strategy | Direct-to-main? |
|------|----------|-----------------|
| soviez-sh | Create remote → `release/0.24.5.2-postcert-corr1` branch → PR → `main` after review | **NOT recommended** for first import without PR |
| Soviez ERP | Branch from `dev`/`main` → PR with **only** `soviez.sh` | Avoid direct-to-main given dirty unrelated tree |
| soviez-deploy | Short PR or direct-to-main acceptable (single clean file) — prefer PR for audit trail | Conditional |
| soviez-saas | Feature/release branch → PR → `main`; deploy `staging` first | **No** direct-to-main for schema |

**MAIN_INTEGRATION_READY = NO** until PP-01..03 closed and PRs prepared.
