# SECURITY_THREAT_MODEL

Threats include forged bundle/manifest/auth; trust-root substitution; downgrade/rollback/stale; replay; theft; Device clone; clock rollback; OCI/addon substitution; path traversal/symlink/archive bomb; exec before verify; USB malware; embedded secrets; Registry leak; key compromise; offline revocation lag; receipt forgery; entitlement/LG/update bypass; cross-tenant issuance; shell injection; privilege escalation.

Mitigations: Ed25519+pinned roots; exact targeting; replay registry; verify-before-extract; quarantine; Phase 15 candidate; no creds in bundle; honest offline revocation limits; no phone-home.
