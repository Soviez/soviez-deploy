# FINAL_REPORT — final-preproduction-live-gate

- captured_utc: 2026-08-16T18:06:15Z
- platform: 0.24.6.2-platform-cli
- artifact_sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- branch: cert/0.24.6.2-platform-cli
- head_commit: 95afdd16441fec6f2e9d4abc69a2a4ffeb7089c2

## Summary

| Area | Status |
|---|---|
| Unit: test_cli_selfupdate_tuning_correction.sh | PASS (40/40) |
| Unit: test_platform_selfupdate_ed25519.sh | PASS (GOOD + negatives) |
| Ubuntu 24.04 live install 0.24.6.2 | PASS |
| Bare PATH CLI from /tmp (no SOVIEZ_ROOT): --version/--list/--stage-list/--tune --dry-run | PASS |
| Self-update 0.24.6.1→0.24.6.2 via staging manifest URL | PASS (with caveats below) |
| Negative badsig fail-closed | PASS |
| Docker/Odoo listeners 8069/8072 | BLOCKED |
| Ubuntu 22.04 retest of 0.24.6.2 | NOT re-run this gate |
| main merge | NOT DONE (not authorized) |

## Corrections in 0.24.6.2

- `src/core/paths.sh`: default `SOVIEZ_ROOT=/var/soviez` + best-effort mkdir
- `src/ssl/paths.sh`: nounset-safe defaults + best-effort mkdir
- `src/platform/install.sh`: `mkdir -p` (was `chmod -p`)
- staging signed manifest schema `soviez.platform_release.v1`

## Staging publication

- artifact_url: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/dist/soviez.sh
- sha256: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- signer_key_id: soviez-platform-staging-2026-08
- channel: staging

## Self-update notes (honest)

1. Unfixed 0.24.6.1 cannot `--platform-install` itself (`chmod -p` / `SOVIEZ_ROOT` unbound). Planted via 0.24.6.2 installer + VERSION pin for the live proof.
2. Apply path runs **installed** `install_from_file`; unfixed 0.24.6.1 needs on-disk `chmod -p`→`mkdir -p` hotfix before apply succeeds.
3. 0.24.6.1 entry still requires `SOVIEZ_ROOT=/var/soviez` (unbound without it). After update, 0.24.6.2 bare PATH works without `SOVIEZ_ROOT`.
4. Positive proof: staging manifest URL → Ed25519 verify → payload SHA `fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193` → `platform updated 0.24.6.1 → 0.24.6.2` → tune dry-run exit 0.
5. GNU `printf` warns on `version_cmp -1` during verify (non-fatal).

## Verdict

**LIVE PATH + STAGING SELF-UPDATE CLEAR for 0.24.6.2 on u2404** (with 0.24.6.1 apply hotfix caveat). Production still gated on ERP listener/Docker proofs. **No main merge.**
