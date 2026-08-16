# FINAL_REPORT — final-preproduction-live-gate

- captured_utc: 2026-08-16T16:20:00Z
- platform: 0.24.6.2-platform-cli
- artifact_sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- branch: cert/0.24.6.2-platform-cli

## Summary

| Area | Status |
|---|---|
| Ubuntu 24.04 live | PASS |
| Ubuntu 22.04 live bare PATH | PASS |
| Fresh install 0.24.6.2 | PASS (24.04 + 22.04) |
| Bare PATH CLI (no SOVIEZ_ROOT) | PASS |
| Self-update 0.24.6.1→0.24.6.2 (staging URL) | PASS (after 0.24.6.1 mkdir hotfix) |
| Self-update negatives | PASS fail-closed (4/4) |
| Unit: CLI selfupdate tuning | PASS (40/0) |
| Unit: platform selfupdate ed25519 | PASS (5/0) |
| Docker/Odoo listeners | BLOCKED |
| Website preview | PARTIAL (prior) |
| Full regression | FAIL (prior) |

## Corrections in 0.24.6.2

- ssl paths else: `_soviez_ssl_root` temps (no `local`)
- core paths: default `SOVIEZ_ROOT=/var/soviez` + best-effort mkdir
- install: `mkdir -p` (was `chmod -p`)
- staging signed manifest schema `soviez.platform_release.v1`

## Staging

- artifact_url: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/platform-release/staging/soviez.sh
- sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- signer_key_id: soviez-platform-staging-2026-08

## Verdict

LIVE PATH + STAGING SELF-UPDATE CLEAR for 0.24.6.2 on u2404 and bare PATH CLEAR on u2204. Production still gated on ERP listener/Docker proofs and full regression. Note: pure self-update from unfixed 0.24.6.1 requires the mkdir hotfix (or bootstrap install of 0.24.6.2) because apply runs the old installer.
