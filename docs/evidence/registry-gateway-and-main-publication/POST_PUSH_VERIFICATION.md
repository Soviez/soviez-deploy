# POST_PUSH_VERIFICATION — Main Integration Checklist

## Status

**PENDING** — awaiting authorized commit/push to remote main.

## Pre-conditions

- [ ] `run_all` on `0.24.5.3-registry-gateway` reports 0 FAIL
- [ ] Owner authorization for main integration (not commercial release)

## soviez-sh

- [ ] Remote configured (PP-01 closure)
- [ ] `.gitignore` on main (PP-02)
- [ ] No `keys.json`, `ticket.token`, `offline-package.json` on remote
- [ ] `dist/soviez.sh` SHA256 = `60b7e320777df5ef95ba192247d3e5b22b34078c2dfb2b1d9fc9955caf7e24dc`
- [ ] `VERSION` = `0.24.5.3-registry-gateway`
- [ ] `services/registry-gateway/` mirror present (no node_modules/dist)
- [ ] Record main SHA in `MAIN_BRANCH_SHAS.md`

## Soviez/soviez-deploy

- [ ] `services/registry-gateway/` published (full operator pack)
- [ ] No secrets in committed env examples
- [ ] `soviez.sh` SHA256 = `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841`
- [ ] Record main SHA

## Soviez/soviez-erp

- [ ] Commit contains **only** `soviez.sh` (PP-04)
- [ ] Wizard SHA matches deploy
- [ ] Record main SHA

## soviez-saas

- [ ] Registry lib + API routes on main
- [ ] Ticket TTL 900s / session 3600s constants deployed
- [ ] Registry tests pass in CI
- [ ] Staging env: gateway URL + ticket public keys configured
- [ ] Record main SHA

## Cross-repo

- [ ] All four SHAs recorded
- [ ] Secret scan on published trees
- [ ] `docs_validate.sh` OK against published dist hash

## Staging smoke (recommended before live cycle)

- [ ] Gateway installed on staging VPS (`registry-staging.soviez.com`)
- [ ] Hub PAT in gateway env (not in git)
- [ ] SaaS issues ticket → docker pull via gateway → manifest 200
- [ ] Upstream credential egress scan on HTTP trace

## Verdict update targets

When complete, update:

- `FINAL_REPORT.md` — MAIN_INTEGRATION_READY
- `MAIN_BRANCH_SHAS.md` — post-push SHAs
- `RUN_ALL_RESULT.md` — if not already filled

Commercial release remains **NOT AUTHORIZED** unless separately approved.
