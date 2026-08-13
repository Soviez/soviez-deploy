# EXCLUSION_MANIFEST_FINAL — Registry Gateway + Main Publication

## Policy

No secrets, dumps, venv, node_modules, or machine temp state in any publish commit.

## soviez-sh — MUST NOT PUBLISH

| Path | Reason |
|------|--------|
| `keys.json` | Root offline key map (PP-03) |
| `ticket.token` | Root ticket credential (PP-03) |
| `offline-package.json` | Offline auth package (PP-03) |
| `.env`, `.env.local` | Local secrets |
| `.tmp/**`, `.tmp.*` | Temp runtime / scratch |
| `**/node_modules/**` | Package installs |
| `services/registry-gateway/dist/` | Rebuildable compile output |
| `services/registry-gateway/node_modules/` | Rebuildable deps |
| `.DS_Store` | OS metadata |
| `*.dump`, `test-filestore/` | Local DB dumps |

## Soviez ERP — MUST NOT PUBLISH (this cycle)

| Path / pattern | Reason |
|----------------|--------|
| `venv/**` | Local Python env |
| `CHANGELOG.md` (unrelated delta) | Pre-existing unrelated change |
| UI / AR_FH dirty paths | Separate workstreams |
| `.DS_Store` | OS junk |
| Everything except `soviez.sh` | PP-04 scope |

## soviez-deploy — MUST NOT PUBLISH

| Path | Reason |
|------|--------|
| Unrelated dirty paths (if any) | Out of cycle scope |
| Build artifacts under gateway if generated locally | Rebuild on deploy host |

## soviez-saas — MUST NOT PUBLISH

| Path | Reason |
|------|--------|
| `.env`, `.env.local`, `.env.production*` | Live env secrets |
| `.next/`, `node_modules/` | Build/cache |
| `.playwright-browsers/`, `test-results/` | Test artifacts |
| Unrelated UI churn without lifecycle contract | Phase 11.5 freeze |

## Gateway-specific exclusions

| Item | Rule |
|------|------|
| Real Hub PAT | Never in git — gateway host only |
| Ticket private keys | SaaS secret store only |
| `*.pem`, `*.key` (non-fixture) | gitignored |
| `config/local/`, `secrets/` | gitignored in gateway package |

## Verification post-push

Re-audit published commits for excluded paths: **PENDING** (`POST_PUSH_VERIFICATION.md`)

## Reference

Prior audit: `docs/evidence/pre-publish-readiness/EXCLUSION_MANIFEST.md` (counts inherited; this cycle adds gateway tree exclusions above).
