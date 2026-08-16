# FRESH_INSTALL_2204

- captured_utc: 2026-08-16T15:19:08Z
- host: lima soviez-u2204 (Ubuntu 22.04.5 LTS Jammy)
- method: customer bootstrap with staging artifact
- artifact_sha256: dc16a4cde22e2e6142706b0e5937237028931ca1c3e352b356a22bfd966e051b
- launcher /usr/local/bin/soviez.sh: PASS
- payload /opt/soviez/platform/current/soviez.sh mode 755 root:root: PASS
- command -v soviez.sh => /usr/local/bin/soviez.sh: PASS
- bare soviez.sh --version from /tmp: FAIL (SOVIEZ_ROOT unbound variable)
- with SOVIEZ_ROOT=/var/soviez: --version/--list/--stage-list/--tune --dry-run: PASS
- full Odoo/Postgres bootstrap: BLOCKED (Docker Engine absent)
