# FINAL_REPORT — final-preproduction-live-gate

- captured_utc: 2026-08-16T15:32:48Z
- platform: 0.24.6.2-platform-cli
- artifact_sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193

## Summary

| Area | Status |
|---|---|
| Ubuntu 24.04 live | PENDING_RETEST |
| Ubuntu 22.04 Jammy recreate | PASS (prior) |
| Fresh CLI install | PENDING_RETEST |
| Bare PATH CLI (no SOVIEZ_ROOT) | PENDING_RETEST |
| CLI with SOVIEZ_ROOT=/var/soviez | PASS (prior) |
| Self-update negatives | PASS (prior) |
| Self-update downgrade | PASS (prior) |
| Self-update positive apply 0.24.6.1→0.24.6.2 | PENDING_RETEST |
| Unit: CLI selfupdate tuning | PASS |
| Unit: platform selfupdate ed25519 | PASS |
| Docker/Odoo listeners | BLOCKED (prior) |
| Website preview | PARTIAL (prior) |

## Corrections in 0.24.6.2

- `src/ssl/paths.sh`: else branch uses `_soviez_ssl_root` temps (no `local`) so PATH CLI works under `set -u`/non-function invoke
- `src/core/paths.sh`: default `SOVIEZ_ROOT=/var/soviez` with best-effort mkdir
- `src/platform/install.sh`: `mkdir -p` for bin/platform roots
- Staging manifest schema `soviez.platform_release.v1`, version `0.24.6.2-platform-cli`, Ed25519 signed

## Staging artifact

- path: platform-release/staging/soviez.sh
- sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- size: 909219
- artifact_url: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/platform-release/staging/soviez.sh
- signer_key_id: soviez-platform-staging-2026-08

## Verdict

CLEAR FOR LIVE RETEST on Lima u2404 (install + bare PATH + staging self-update). Production release still gated on ERP listener proofs.
