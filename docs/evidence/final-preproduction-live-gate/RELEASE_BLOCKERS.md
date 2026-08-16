# RELEASE_BLOCKERS — final-preproduction-live-gate

Updated for platform `0.24.6.2-platform-cli` (after SOVIEZ_ROOT + mkdir -p fixes).

## Cleared in 0.24.6.2

1. ~~SOVIEZ_ROOT unbound bare PATH CLI~~ — FIXED (default `/var/soviez`)
2. ~~`chmod -p` install bug~~ — FIXED (`mkdir -p`)
3. Staging Ed25519 self-update positive path (u2404) — PASS
4. Bare PATH `/tmp` CLI (u2404) — PASS

## Remaining blockers (owner gate)

1. **BLOCKED:** Full Odoo/PostgreSQL/Docker listener live matrix (8069/8072 loopback, nginx WebSocket HTTP 101, tune effective `pg_settings`, ClamAV daemon/on-access, quarantine egress, backup/restore live) — Lima VMs lack Docker Engine / full ERP stack in this run.
2. **BLOCKED:** Ubuntu 22.04 full parity retest of 0.24.6.2 (22.04 host recreated as Jammy earlier; 0.24.6.2 PATH/self-update proven on 24.04; 22.04 0.24.6.2 install retest optional follow-up).
3. **FAIL:** Canonical `tests/run_all.sh` — exit 1 (~57 FAIL / ~335 OK); see `FULL_REGRESSION.md`.
4. **PARTIAL:** Vercel Preview — branch `preview/public-docs-sync` pushed (`41da9f4`); branch alias requires Vercel Authentication / SSO; CLI token expired for deployment API listing.
5. **WARN:** GNU `printf` mishandles `version_cmp` returning `-1` in some verify paths (non-fatal).
6. **POLICY:** Main merge, Production website cutover, stable commercial release, customer rollout — **NOT AUTHORIZED**.

## Recommended next gate

1. Provision disposable Ubuntu 22.04 + 24.04 hosts **with Docker Engine, systemd, AppArmor, UFW** and run Parts E–M live ERP matrix.
2. Triage/fix `tests/run_all.sh` FAIL set (ledger.py / Phase 20–25).
3. Refresh Vercel CLI auth; confirm Preview deployment for `41da9f4`; owner SSO review of `/sh-landing` + `/docs`.
4. Owner authorization for main merge / stable channel only after live ERP PASS.
