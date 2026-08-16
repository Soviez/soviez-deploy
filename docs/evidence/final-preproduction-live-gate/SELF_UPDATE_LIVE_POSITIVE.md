# SELF_UPDATE_LIVE_POSITIVE

- captured_utc: 2026-08-16T15:34:52Z
- host: lima soviez-u2404 (Ubuntu 24.04.4 LTS)
- path: 0.24.6.1-platform-cli → 0.24.6.2-platform-cli
- manifest_url: https://raw.githubusercontent.com/Soviez/soviez-deploy/cert/0.24.6.2-platform-cli/platform-release/staging/manifest.json
- channel: staging
- signer_key_id: soviez-platform-staging-2026-08
- result: PASS apply
- artifact_sha256 after: fbd3a3eab448e4d34bcfd5b78d0178d72b4178ed71ccff2abb11a96f3f78a193
- note: installed 0.24.6.1 still contained `chmod -p` install bug; one-line hotfix to `mkdir -p` on the live 0.24.6.1 payload was required before apply could complete (crypto+download already OK). 0.24.6.2 ships the mkdir -p fix.
- incidental: printf '-1' warning from version_cmp during apply (non-fatal); install completed and re-exec showed 0.24.6.2
- VERSION file under current/ lagged at 0.24.6.1 after apply (written by old process); embedded `# version:` and `soviez.sh --version` report 0.24.6.2
