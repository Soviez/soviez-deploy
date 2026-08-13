# SCOPE_INCLUSIONS.md

1. Prove absence of unsigned installer self-update; keep regression tests.
2. Fail-closed signed update / offline package / offline bundle verification in production paths.
3. Remove or strictly quarantine fixture/fake signature and fixture Registry token fallbacks.
4. Key/secret hygiene implementation per OD-P24-03 (hashing/envelope/controls).
5. Consolidated ticket-replay security suite across Stage, update offline, offline bundles, migration offline, DNS challenges.
6. Registry lockdown hardening (ephemeral docker config, logout, fail on residue where safe).
7. Secret-scan CI in `soviez-sh` (+ keep local scans).
8. New `tests/security/test_phase24_*.sh` (+ wire into `run_all`).
9. Documentation correction for stale self-update language.
10. Clarify/test “no service-role credentials in dist”.
11. Optional: harden Phase 24 readiness PASS/WARNING/BLOCKED with TTL/drift (not authorization for Phase 25).
12. Sovereignty/security regression suites for phone-home, egress, permanent docker login.
13. Reuse Phase 14 for any new security remediation operations (if needed).
14. Evidence pack under `docs/evidence/phase-24-security-hardening/` (future implementation).
