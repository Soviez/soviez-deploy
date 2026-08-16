# RELEASE_BLOCKERS

## Cleared in 0.24.6.2
1. ~~SOVIEZ_ROOT unbound bare PATH CLI on 0.24.6.2~~ → fixed (default `/var/soviez` + best-effort mkdir)
2. ~~`chmod -p` platform install in 0.24.6.2~~ → fixed (`mkdir -p`); live apply PASS on u2404 when running installer is 0.24.6.2 (or hotfixed 0.24.6.1)
3. ~~Staging Ed25519 GOOD / badsig fail-closed~~ → unit + live PASS

## Still open (blocks commercial / full live PASS)
1. **BLOCKED:** Docker/Odoo/PostgreSQL full stack inside Lima — no listeners 8069/8072, nginx WebSocket 101, PG privilege live matrix, ClamAV, quarantine egress, backup/restore live
2. **BLOCKED:** Pure self-update from **unfixed** 0.24.6.1 without on-disk `mkdir` hotfix (apply uses old `install_from_file`). Workaround: bootstrap install 0.24.6.2, or hotfix installed 0.24.6.1 before update
3. **BLOCKED:** Ubuntu 22.04 live retest of 0.24.6.2 PATH/self-update not re-run in this corrective gate
4. **PARTIAL:** Vercel Preview / public docs sync — prior SSO/deployment-protection limits
5. **FAIL:** Full `tests/run_all.sh` still not green (historical ~335 OK / ~57 FAIL; not re-run as gate scope)
6. **WARN:** GNU `printf` mishandles `version_cmp` `-1` in some verify paths (non-fatal)

## Authorization stops
- MAIN MERGE = NOT AUTHORIZED
- PRODUCTION WEBSITE CUTOVER = NOT AUTHORIZED
- STABLE COMMERCIAL RELEASE = NOT AUTHORIZED
- CUSTOMER DEPLOYMENT = NOT AUTHORIZED
