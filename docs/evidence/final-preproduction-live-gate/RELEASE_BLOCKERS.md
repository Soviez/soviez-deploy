# RELEASE_BLOCKERS

## Cleared in 0.24.6.2
1. ~~SOVIEZ_ROOT unbound bare PATH CLI~~ → fixed (`SOVIEZ_ROOT` default `/var/soviez`)
2. ~~`chmod -p` platform install~~ → fixed (`mkdir -p`); live self-update apply PASS on u2404

## Still open (blocks commercial / full live PASS)
1. **BLOCKED:** Docker/Odoo/PostgreSQL full stack inside Lima — no listeners 8069/8072, nginx WebSocket 101, PG privilege live matrix, ClamAV daemon/on-access, quarantine egress, backup/restore live
2. **BLOCKED:** Ubuntu 22.04 live retest of 0.24.6.2 PATH/self-update not fully re-run after bump (22.04 host exists from prior gate; 0.24.6.2 live proofs recorded on 24.04)
3. **PARTIAL:** Vercel Preview — branch pushed (`preview/public-docs-sync` @ `41da9f4`); SSO/deployment-protection blocks anonymous review; CLI token expired for API listing
4. **FAIL:** Full `tests/run_all.sh` exit 1 — see `FULL_REGRESSION.md` (~335 OK / ~57 FAIL; includes phase20–22 ledger and Phase 25 partials)
5. **WARN:** GNU `printf` mishandles `version_cmp` `-1` in some verify paths (non-fatal)

## Authorization stops
- MAIN MERGE = NOT AUTHORIZED
- PRODUCTION WEBSITE CUTOVER = NOT AUTHORIZED
- STABLE COMMERCIAL RELEASE = NOT AUTHORIZED
- CUSTOMER DEPLOYMENT = NOT AUTHORIZED
