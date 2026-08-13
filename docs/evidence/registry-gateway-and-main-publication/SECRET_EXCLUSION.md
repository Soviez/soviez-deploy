# SECRET_EXCLUSION — PP-03

## Verdict

**PASS** (gitignore + policy)

## Blocker

| ID | Description | Status |
|----|-------------|--------|
| PP-03 | Root secrets must stay untracked | **CLOSED** |

## Explicit root exclusions

| Path | Classification | Action |
|------|----------------|--------|
| `keys.json` | SECRET_OR_SENSITIVE | `.gitignore` — DO NOT PUBLISH |
| `ticket.token` | SECRET_OR_SENSITIVE | `.gitignore` — DO NOT PUBLISH |
| `offline-package.json` | SECRET_OR_SENSITIVE | `.gitignore` — DO NOT PUBLISH |

## Gateway secrets (never in git)

| Secret | Allowed location |
|--------|------------------|
| Hub user/token | Gateway host `/etc/soviez-registry-gateway/gateway.env` |
| Ticket private keys | SaaS env / secret store |
| Ticket public keys | Gateway env (public material, still ops-managed) |
| TLS private keys | Host cert paths (nginx) |

## Example files

All committed env examples use placeholders only:

- `soviez-sh/services/registry-gateway/.env.example`
- `soviez-sh/services/registry-gateway/config/gateway.env.example`

## Gateway package

No real secrets in:

- Source tree
- `dist/` build output (rebuildable, gitignored under `services/*/dist/`)
- Test fixtures (synthetic secrets only, asserted non-egress)

## Scan status

Prior pre-publish secret scan: **PASS** (`docs/evidence/pre-publish-readiness/SECRET_SCAN.md`).

This cycle adds gateway tree — no new root secret files introduced.

## Post-push verification

Re-run secret scan on published trees; confirm three root files absent from remote: **PENDING**
