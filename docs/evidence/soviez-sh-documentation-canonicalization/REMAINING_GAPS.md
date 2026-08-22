# Remaining Gaps

## Documentation gaps

| Gap | Action |
|-----|--------|
| Full sync of all 43 public-docs from deploy user tree | Partial — 10 files synced; run `npm run sync:public-docs` on authorized commit |
| `docs/security/UPDATE_SAFETY.md` still pins `0.24.5.1` | Low priority; add supersession note on next pass |
| Architecture `RELEASE_MODEL.md` | Consolidated into `docs/releases/RELEASE_NAMING_AND_IMMUTABILITY.md` |

## Runtime gaps (documented, not fixed this mission)

| Feature | Status |
|---------|--------|
| Modular PATH `--init` | APPROVED_NOT_IMPLEMENTED |
| `--doctor`, `--release-status`, `--releases`, `--safe-mode` | APPROVED_NOT_IMPLEMENTED |
| `--tune --explain`, `--tune` apply live | APPROVED / NOT_CERTIFIED |
| ClamAV on every `--init` | Converging |
| Full Odoo live stack on Lima | BLOCKED (ERP image) |
| Connected self-update staging manifest | BLOCKED (not pushed) |

## Owner decision required

1. Authorize commit of documentation canonicalization on `cert/0.24.6.2-platform-cli` and `preview/public-docs-sync`.
2. Authorize modular `--init` implementation schedule (PATH CLI convergence).
3. Authorize ERP image availability for live certification closure.
