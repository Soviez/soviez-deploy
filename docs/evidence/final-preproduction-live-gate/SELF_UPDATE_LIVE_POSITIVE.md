# SELF_UPDATE_LIVE_POSITIVE

- captured_utc: 2026-08-16T18:06:15Z
- host: soviez-u2404
- channel: staging
- manifest_url: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/platform-release/staging/manifest.json
- SELFUP 0.24.6.1 → 0.24.6.2: **PASS** (payload SHA fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193; log: platform updated; tune dry-run EC=0)
- Preconditions for PASS from planted 0.24.6.1: on-disk `chmod -p`→`mkdir -p` hotfix + `SOVIEZ_ROOT=/var/soviez` for 0.24.6.1 entry
- Unfixed 0.24.6.1 apply without hotfix: FAIL (documented)
