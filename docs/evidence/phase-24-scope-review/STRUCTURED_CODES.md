# STRUCTURED_CODES.md

Phase 24-specific codes (proposal):

| Code | Meaning |
|------|---------|
| `SECURITY_READINESS_REQUIRED` | Hardening gates not met |
| `SECURITY_READINESS_EXPIRED` | If TTL added to readiness |
| `SECURITY_READINESS_DRIFT` | Artifact/SHA/policy drift |
| `SECURITY_TARGET_MISMATCH` | Wrong License/env/host |
| `SECURITY_CONFLICT` | Conflicting operation active |
| `SECURITY_UNSIGNED_UPDATE_FORBIDDEN` | Unsigned/self-update/soft-sig denied |
| `SECURITY_SIGNATURE_INVALID` | Bad signature |
| `SECURITY_FAKE_SIGNATURE_FORBIDDEN` | Fixture sig outside TEST_MODE |
| `SECURITY_REGISTRY_LOCKDOWN` | Cred residue / permanent login |
| `SECURITY_SECRET_SCAN_FAILED` | CI/local scan failed |
| `SECURITY_SERVICE_ROLE_IN_DIST` | Credential pattern in dist |
| `SECURITY_KEY_HYGIENE_REQUIRED` | At-rest secret policy unmet |
| `SECURITY_TICKET_REPLAY` | Replay detected / ledger fail |
| `SECURITY_CERTIFICATION_FAILED` | Suite aggregate fail |
| `SECURITY_RECOVERY_REQUIRED` | Interrupted remediation op |
| `PHASE25_NOT_READY` | Phase 24 incomplete / handoff blocked |

Reuse existing update/offline/migration codes where semantics already exist; do not duplicate.
