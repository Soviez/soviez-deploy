# EXCLUSION_MANIFEST

## Counts (approximate / exact where stated)

| Repo | Excluded items | Primary reasons |
|------|---------------:|-----------------|
| soviez-sh | **9330** files under ignore patterns | `.tmp/`, `.tmp.*`, `node_modules`, `.DS_Store`, root secrets |
| Soviez ERP | **~137** dirty paths | `venv/**`, `.DS_Store`, unrelated CHANGELOG/business modules, local browsers |
| soviez-deploy | **0** cycle exclusions (only `soviez.sh` dirty) | — |
| soviez-saas | **~41+** env/playwright + **~74** UI/review paths | secrets, browsers, Phase 11.5 UI freeze debate |

## soviez-sh — MUST NOT PUBLISH (explicit)

| Path | Classification | Reason |
|------|----------------|--------|
| `keys.json` | SECRET_OR_SENSITIVE | Offline key material at repo root |
| `ticket.token` | SECRET_OR_SENSITIVE | JWT/ticket credential at repo root |
| `offline-package.json` | SECRET_OR_SENSITIVE | Offline auth package fixture with live-shaped claims |
| `.tmp/**` | LOCAL_TEST_ONLY / SECRET_OR_SENSITIVE | Keys, dumps, reboot/migration scratch (~224MB) |
| `.tmp.*` (root) | TEMPORARY | mktemp leftovers |
| `**/node_modules/**` | DO_NOT_PUBLISH | Package installs under `services/*` |
| `.DS_Store` | DO_NOT_PUBLISH | macOS metadata |
| Any `*.dump` under `.tmp` | DO_NOT_PUBLISH | DB dumps |

Partial exclusion listing: `_exclusion_soviez_sh.tsv` (truncated listing + total).

## Soviez ERP — MUST NOT PUBLISH with this cycle

| Path / pattern | Classification | Reason |
|----------------|----------------|--------|
| `venv/**` | LOCAL_ENVIRONMENT_ONLY | Local Python env churn |
| `CHANGELOG.md` (current delta) | PREEXISTING_UNRELATED_CHANGE | Partner Subledger / Lugmety releases — not Soviez.sh cycle |
| UI architecture / AR_FH evidence (if present dirty) | PREEXISTING_UNRELATED_CHANGE | Separate ERP workstreams |
| `.DS_Store` | DO_NOT_PUBLISH | OS junk |
| `.playwright-browsers/` if present | LOCAL_TEST_ONLY | Browsers |

**Publish only:** `soviez.sh` (cycle).

## soviez-saas — MUST NOT PUBLISH

| Path / pattern | Classification | Reason |
|----------------|----------------|--------|
| `.env`, `.env.local`, `.env.live`, `.env.production`, `.env.production.local` | SECRET_OR_SENSITIVE | Live/prod env (gitignore present — verify stay untracked) |
| `.playwright-browsers/`, `playwright-report/`, `test-results/` | LOCAL_TEST_ONLY | Browser/cache artifacts |
| Unrelated marketing/checkout UI churn without lifecycle contract | OWNER_DECISION / may be PREEXISTING | Phase 11.5 visual freeze — do not conflate with backend publish |

## Policy
No secrets, dumps, venv, node_modules, or machine temp state in any publish commit.
