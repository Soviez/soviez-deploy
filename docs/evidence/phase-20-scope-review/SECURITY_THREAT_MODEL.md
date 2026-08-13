# SECURITY_THREAT_MODEL.md

| Threat | Mitigation |
|--------|------------|
| Forged authorization / SaaS response | Signatures; pinned signer keys; TLS; verify request hash |
| Wrong account/License/pair/device | Exact targeting + fingerprint bind |
| Stale Phase 19 readiness | Fingerprint + expiry |
| Replay / double spend | Idempotency + replay registry + grant consume once |
| Token theft / cross-License use | PoP device auth; License bind; entitlement scope |
| Duplicate destination binding | Unique constraints + locks |
| Dual unrestricted Production | Anti-split-brain + grace restrictions |
| LG bypass | Fail-closed guard; no unsigned bind |
| Offline forgery/replay | Signed package; expiry; replay ledger; reconcile |
| Clock rollback | Skew limits; max lifetime |
| Stage hijack / cross-tenant | Parent License checks |
| Public dest early | Route probes; BLOCKED |
| Source grace abuse | Capability deny list |
| Unauthorized compensation | Admin role + audit |
| Secret leakage / shell injection | Redaction; no secrets in argv; path allowlists |
| Broad cleanup | Exact-owned only |
| Malicious Root | Honest boundary: Root can sabotage host; design fail-closed + audit, not Root-proof |

Malicious Root boundary: document honestly — physical/root host compromise can destroy local state; commercial truth remains SaaS; recovery via idempotency query + re-apply.
