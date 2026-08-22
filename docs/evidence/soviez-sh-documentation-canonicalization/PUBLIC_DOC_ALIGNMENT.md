# Public Doc Alignment

**Branch:** `preview/public-docs-sync` (soviez-saas)  
**Production website:** NOT changed  
**Preview source:** UPDATED

## Synced files (this pass)

- `QUICK_START.md`, `PRODUCT_OVERVIEW.md`, `INITIALIZATION.md`, `SECURITY.md`, `INSTALLATION.md`, `WEBSOCKET_AND_LONGPOLLING.md`, `TUNING.md`
- `SOVIEZ_SH_PRODUCT_CONTRACT.md`, `IMPLEMENTATION_STATUS_MATRIX.md`, `SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md`

## Validation

| Check | Result |
|-------|--------|
| `npm run test:public-docs` | **PASS** (18/18) |
| `./dist/soviez.sh` on public surface | 0 |
| `./soviez.sh` on public surface | 0 |
| `--merge-in` on public surface | 0 |
| `--formworkers` on public surface | 0 |

## Withheld from public claims

`--doctor`, `--release-status`, `--releases`, `--safe-mode`, `--tune --explain` — listed in implementation matrix as APPROVED_NOT_IMPLEMENTED.

## Registry Gateway

Public docs may describe customer pull behavior; internal Gateway server implementation not published in deploy repo per D131.
