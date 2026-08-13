# COMMIT_STRATEGY (recommendation only — DO NOT COMMIT NOW)

## soviez-sh (initial import)
1. Commit A: `.gitignore` + `.gitleaks.toml`
2. Commit B: `src/` `build/` `share/` `schemas/` `services/`(no node_modules) `VERSION` constitutions
3. Commit C: `tests/` `tools/` `scripts/` `tooling/`
4. Commit D: `dist/soviez.sh` + sha256
5. Commit E: canonical `docs/` (non-evidence)
6. Commit F: `docs/evidence/` (or summaries-first if owner prefers)

Avoid hundreds of micro-commits. 4–6 logical commits is enough.

## Soviez ERP
- **One commit**: `soviez.sh` only — message references post-cert WS/proxy_mode/workers parity

## soviez-deploy
- **One commit**: `soviez.sh` — must match ERP hash; note cross-repo parity

## soviez-saas
- Logical groups: (1) migrations 078–090 (2) libs/APIs (3) admin/installer UI needed for ops (4) package lock/types
- Do **not** mix Partner-unrelated work; do not commit `.env` or playwright browsers
