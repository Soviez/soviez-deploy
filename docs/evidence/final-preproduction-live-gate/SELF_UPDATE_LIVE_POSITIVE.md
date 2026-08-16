# SELF_UPDATE_LIVE_POSITIVE

- captured_utc: 2026-08-16T16:20:00Z
- host: lima soviez-u2404 (Ubuntu 24.04)
- path: 0.24.6.1-platform-cli → 0.24.6.2-platform-cli
- manifest_url: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/platform-release/staging/manifest.json
- channel: staging
- signer_key_id: soviez-platform-staging-2026-08
- result: PASS apply
- artifact_sha256 after: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- method notes:
  - installing stock 0.24.6.1 via `--platform-install` fails closed on `chmod -p` (expected pre-fix installer bug)
  - forced current payload to stock 0.24.6.1 (`dc16a4…`), applied one-line `chmod -p`→`mkdir -p` hotfix on the live 0.24.6.1 payload, then invoked `soviez.sh --platform-install` with staging manifest URL
  - update log: `platform updated 0.24.6.1-platform-cli → 0.24.6.2-platform-cli; re-executing`
  - incidental: GNU `printf` warns on `version_cmp` `-1` during apply (non-fatal)
- raw: `SELF_UPDATE_LIVE_POSITIVE_RERUN.txt`
