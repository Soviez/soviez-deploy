# SAAS_MAIN_DIFF — soviez-saas Main Integration

## Status

**PENDING** — push not done; diff not finalized on remote main.

## Expected scope (this cycle)

Registry pull-session control plane supporting gateway offline verify:

| Area | Paths |
|------|-------|
| Registry service | `src/lib/registry/**` |
| Installer API | `src/app/api/installer/registry/**` |
| Constants / ticket contract | TTL 900s, session 3600s, repo `soviez/soviez-erp` |
| Migrations | Registry/stage-related SQL (078–090 series) |

## Key contract constants (already in tree)

| Constant | Value |
|----------|-------|
| `REGISTRY_PROTOCOL_VERSION` | `registry-pull/v1` |
| `REGISTRY_TICKET_SIGNING_DOMAIN` | `soviez.registry-pull-ticket.v1` |
| `PULL_CREDENTIAL_TTL_SECONDS` | 900 |
| `PULL_SESSION_MAX_LIFETIME_SECONDS` | 3600 |
| `REGISTRY_REPOSITORY_ALLOWLIST` | `soviez/soviez-erp` |

## Remote

| Field | Value |
|-------|-------|
| Repository | soviez-saas |
| Target branch | `main` |
| Pre-push main SHA | **PENDING** |
| Post-push main SHA | **PENDING** |

## Verification after push

- [ ] `src/lib/registry/logic.test.ts` passes in CI
- [ ] `src/lib/registry/e2e/certification.test.ts` passes
- [ ] No env secrets in commit
- [ ] Gateway public key env documented for staging

See `POST_PUSH_VERIFICATION.md`.
