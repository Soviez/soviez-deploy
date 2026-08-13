# GITIGNORE_CLOSURE — PP-02

## Verdict

**PASS** — `.gitignore` added to soviez-sh

## Blocker

| ID | Description | Status |
|----|-------------|--------|
| PP-02 | soviez-sh missing `.gitignore` | **CLOSED** |

## File

`soviez-sh/.gitignore`

## Key patterns added

| Pattern | Purpose |
|---------|---------|
| `.env`, `.env.*` (except `.env.example`) | Local env secrets |
| `keys.json` | Offline key map at repo root |
| `ticket.token` | Ticket credential at repo root |
| `offline-package.json` | Offline auth package |
| `docker-auth/`, `config.json` | Docker credential dirs |
| `.tmp/`, `.tmp.*`, `tmp/` | Temp runtime |
| `node_modules/` | Node deps |
| `services/*/dist/`, `services/*/node_modules/` | Service build artifacts |
| `*.p12`, `*.pfx` | Private key material |
| `venv/`, `.venv/` | Python env |
| `*.dump`, `test-filestore/` | Local data |

## Gateway service gitignore

`soviez-sh/services/registry-gateway/.gitignore` additionally excludes:

- `node_modules/`, `dist/`
- `.env*`, `*.pem`, `*.key`, `secrets/`
- `data/`, `logs/`, `backups/`

## Verification

| Check | Result |
|-------|--------|
| Root secrets listed in gitignore | PASS |
| Service build artifacts excluded | PASS |
| Synthetic test fixtures allowed under `tests/**/fixtures/**` | PASS (negation rules) |

## Pre-publish audit reference

Prior audit: `docs/evidence/pre-publish-readiness/GITIGNORE_AUDIT.md` (recommended patterns now applied).

## Post-push verification

Confirm no tracked files under ignore patterns on remote main: **PENDING** (`POST_PUSH_VERIFICATION.md`)
