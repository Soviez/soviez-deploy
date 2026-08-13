# Changed files (Phase 24 implementation)

## Created
- src/security/*.sh (codes, test_flag_policy, signatures, signer_purpose, key_fingerprints, secret_hygiene, registry_hygiene, replay_audit, dist_scan, readiness)
- tools/secret_scan.sh, .gitleaks.toml
- tests/security/test_phase24_*.sh, run_phase24_security.sh
- tests/security/fixtures/secrets/* (synthetic)
- docs/ai/SECURITY_HARDENING_MODEL.md, docs/dev/* Phase 24, docs/user/SECURITY_VERIFICATION.md
- docs/evidence/phase-24-security-hardening/*

## Modified
- build/assemble.sh (wire security modules)
- src/update/release.sh, src/update/offline.sh
- src/offline_trust/keys.sh, src/migration/pairing/offline.sh
- src/offline_bundle/export/registry.sh, src/tenant/secrets.sh
- src/cli/parse.sh, src/entrypoint.sh
- src/offline_bundle/package.sh, import.sh, src/offline_update/apply.sh (version)
- docs/user/PRIVACY_AND_SOVEREIGNTY.md
- VERSION → 0.24.0-phase24
- tests/security/test_phase20/21/22_static_forbidden.sh (version allow-list)
- PROJECT_STATE.md, docs/ai/CURRENT_STATE.md, MASTER_IMPLEMENTATION_PLAN.md, DECISION_LOG.md (on PASS)
