# CLI_PATH_LIVE

- captured_utc: 2026-08-16T16:20:00Z
- hosts: lima soviez-u2404 (24.04) and soviez-u2204 (22.04)
- platform: 0.24.6.2-platform-cli
- artifact_sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- PASS: launcher `/usr/local/bin/soviez.sh --version` without `SOVIEZ_ROOT` (both hosts)
- PASS: from `/tmp` without `SOVIEZ_ROOT`: `--version`, `--list`, `--stage-list`, `--tune --dry-run`
- PASS: defaults `SOVIEZ_ROOT=/var/soviez`; ssl paths use `_soviez_ssl_root` temps (no unbound `local`)
- note: readonly self-update probe may curl `main/platform-release/staging` (404) when channel=staging without `SOVIEZ_PLATFORM_MANIFEST_URL`; does not break `--version` when `SOVIEZ_SKIP_PLATFORM_UPDATE=1` / offline
