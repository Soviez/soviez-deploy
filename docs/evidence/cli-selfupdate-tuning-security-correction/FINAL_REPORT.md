# FINAL REPORT — CLI / Self-Update / Tuning / Multi-Worker / Security Correction

**Date:** 2026-08-16  
**Artifact:** `0.24.6.0-platform-cli`  
**SHA256:** `7265a248fef5bf88c1d0d0c67fcfed8604eabd151b1f8ebf1bc4f83cce33da6f`  
**Previous:** `0.24.5.3-registry-gateway` / `68ab59972d84d34f38c43862ca28946d3df3da5707fefa970230bd43e1da3460`

## Verdict

```text
IMPLEMENTATION PASS — FIXTURE / UNIT / CONTRACT CERTIFIED
LIVE_UBUNTU_HOST_ACCEPTANCE = PENDING (not run on disposable Ubuntu LTS in this cycle)
COMMERCIAL RELEASE = NOT AUTHORIZED
PRODUCTION WEBSITE CUTOVER = NOT AUTHORIZED
```

## What passed in this cycle

- PATH launcher architecture (`/usr/local/bin/soviez.sh` → `/opt/soviez/platform/current/`)
- Public bootstrap installs modular platform (legacy wizard moved to `legacy/`)
- Legacy unsigned `update_self` retired (fail-closed)
- `--version`, `--list`, `--stage-list` (corrupt inventory clean failure)
- `--tune` / `--tune --dry-run` + sizing engine + idempotency + rollback helper
- Multi-worker topology: HTTP 8069 + gevent 8072; Nginx templates updated
- WebSocket HTTP 101 fixture test
- ClamAV complementary module + YARA preserved; quarantine filestore hooks ClamAV
- Canonical docs + Preview working tree synced (no commit/push/deploy)
- Correction matrix: 40/40 PASS; postcert WS matrix: 17/17 PASS
- Public docs unit tests: 17/17 PASS

## Remaining for full live certification

- Disposable Ubuntu 22.04/24.04 guest: AppArmor, UFW/Docker firewall proof, Fail2Ban regex, unattended-upgrades, ClamAV daemon/freshclam/EICAR-safe, PG role live deny matrix, full Odoo login/PDF/XLSX/cron acceptance, quarantine egress container proof
- Publish signed `platform-release/stable/manifest.json` to GitHub (required for connected self-update in the wild)
- Vercel Preview redeploy of `preview/public-docs-sync` (working tree updated only)

## Git safety

No commits, pushes, merges, tags, Production deploys, or website cutovers performed.
