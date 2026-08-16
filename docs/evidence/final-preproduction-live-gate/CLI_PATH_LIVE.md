# CLI_PATH_LIVE

- captured_utc: 2026-08-16T15:34:52Z
- host: lima soviez-u2404
- platform: 0.24.6.2-platform-cli
- PASS: launcher /usr/local/bin/soviez.sh --version without SOVIEZ_ROOT
- PASS: /tmp/soviez-bare.sh --version without SOVIEZ_ROOT
- PASS: defaults SOVIEZ_ROOT=/var/soviez; ssl paths else uses _soviez_ssl_root temps (no local)
- note: readonly self-update probe may curl main/platform-release/staging (404) when channel=staging without SOVIEZ_PLATFORM_MANIFEST_URL; does not break --version
