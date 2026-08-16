# CLI_PATH_LIVE

- captured_utc: 2026-08-16T15:19:08Z
- PASS: launcher at /usr/local/bin/soviez.sh on 22.04 and 24.04
- PASS: CWD-independent wrapper to /opt/soviez/platform/current/soviez.sh
- FAIL: bare soviez.sh without SOVIEZ_ROOT crashes (ssl paths init uses unbound SOVIEZ_ROOT)
- WORKAROUND: sudo env SOVIEZ_ROOT=/var/soviez soviez.sh ...
- PASS with workaround: --help --version --list --stage-list --tune --dry-run
