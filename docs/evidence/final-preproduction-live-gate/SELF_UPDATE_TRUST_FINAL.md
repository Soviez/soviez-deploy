# SELF_UPDATE_TRUST_FINAL

- algorithm: Ed25519
- signer_key_id: soviez-platform-staging-2026-08
- public fingerprint SHA256: 18796949cebb7239fa21475c8b3709286ee1bfb487ec96faeb32450d640e93d5
- public keys shipped in share/platform-trust and live /opt/soviez/platform/current/trust
- private keys host-only under .secrets/staging-platform-keys (never in VMs/evidence)
- negatives live: PASS fail-closed
- positive apply: BLOCKED by chmod -p
- SELFUP-LIVE-09 readonly with unreachable update URL: PASS
