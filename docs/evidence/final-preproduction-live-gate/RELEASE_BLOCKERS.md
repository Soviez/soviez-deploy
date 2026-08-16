# RELEASE_BLOCKERS

## Cleared in 0.24.6.2
1. ~~SOVIEZ_ROOT unbound bare PATH CLI~~ → fixed (`SOVIEZ_ROOT` default `/var/soviez`)
2. ~~`chmod -p` platform install~~ → fixed (`mkdir -p`); live self-update apply PASS on u2404
3. ~~Ubuntu 22.04 bare PATH retest~~ → PASS on soviez-u2204 for 0.24.6.2 install + readonly CLI

## Still open (blocks commercial / full live PASS)
1. **BLOCKED:** Docker/Odoo/PostgreSQL full stack inside Lima — no listeners 8069/8072, nginx WebSocket 101, PG privilege live matrix, ClamAV daemon/on-access, quarantine egress, backup/restore live
2. **PARTIAL:** Vercel Preview — branch pushed (`preview/public-docs-sync`); SSO/deployment-protection blocks anonymous review; CLI token issues for API listing may remain
3. **FAIL:** Full `tests/run_all.sh` exit 1 — see `FULL_REGRESSION.md`
4. **WARN:** GNU `printf` mishandles `version_cmp` `-1` in some verify paths (non-fatal)
5. **NOTE:** Pure self-update from unfixed 0.24.6.1 still requires the `mkdir -p` hotfix (or bootstrap install of 0.24.6.2) because apply runs the old installer

## Authorization stops
- MAIN MERGE = NOT AUTHORIZED
- PRODUCTION WEBSITE CUTOVER = NOT AUTHORIZED
- STABLE COMMERCIAL RELEASE = NOT AUTHORIZED
- CUSTOMER DEPLOYMENT = NOT AUTHORIZED
