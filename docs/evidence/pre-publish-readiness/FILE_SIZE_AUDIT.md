# FILE_SIZE_AUDIT

| Path | Size | Purpose | Publish? |
|------|------|---------|----------|
| `dist/soviez.sh` | ~1.6MB | Certified installer | YES |
| `docs/evidence/` | ~8.8MB | Certification markdown | YES (policy OK) |
| `.tmp/` | ~224MB | Local test state, dumps, keys | **NO** |
| `services/*/node_modules/**` | multi-MB binaries (esbuild, typescript) | Dependencies | **NO** — use package locks/install |
| ERP `venv/` | large | Local Python | **NO** |

No DB dump should enter Git. No accidental binary from `.tmp` or `node_modules`.
