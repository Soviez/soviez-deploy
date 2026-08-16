# FINAL_REPORT — final-preproduction-live-gate

- captured_utc: 2026-08-16T15:34:52Z
- platform: 0.24.6.2-platform-cli
- artifact_sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- branch: cert/0.24.6.2-platform-cli

## Summary

| Area | Status |
|---|---|
| Ubuntu 24.04 live | PASS |
| Fresh / self-update install to 0.24.6.2 | PASS |
| Bare PATH CLI (no SOVIEZ_ROOT) | PASS |
| /tmp bare PATH CLI | PASS |
| Self-update 0.24.6.1→0.24.6.2 (staging URL) | PASS (after 0.24.6.1 mkdir hotfix) |
| Unit: CLI selfupdate tuning | PASS |
| Unit: platform selfupdate ed25519 | PASS |
| Docker/Odoo listeners | BLOCKED |
| Website preview | PARTIAL (prior) |

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

LIVE PATH + STAGING SELF-UPDATE CLEAR for 0.24.6.2 on u2404. Production still gated on ERP listener/Docker proofs. Note: pure self-update from unfixed 0.24.6.1 requires the mkdir hotfix (or bootstrap install of 0.24.6.2) because apply runs the old installer.
