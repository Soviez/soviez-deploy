# SELF_UPDATE_TRUST_FINAL

- algorithm: Ed25519
- signer_key_id: soviez-platform-staging-2026-08
- public fingerprint (documented): SHA256:18796949cebb7239fa21475c8b3709286ee1bfb487ec96faeb32450d640e93d5
- public key shipped:  (and  on live hosts)
- private key: host-only  mode 600 — **never** copied into VMs or evidence
- live fail-closed negatives: PASS
- live positive apply: BLOCKED by  install defect
- SELFUP-LIVE-07 interrupt: BLOCKED/incomplete (FIFO candidate hang + chmod bug); payload preserved
- SELFUP-LIVE-09 readonly with update unreachable: PASS ( rc=0)
