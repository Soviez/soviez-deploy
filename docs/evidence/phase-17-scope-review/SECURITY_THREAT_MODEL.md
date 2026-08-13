# Security Threat Model — Phase 17

## Threats and mitigations

| Threat | Mitigation |
|--------|------------|
| Forged destination | Exact host fingerprint + owner confirm + signed pair |
| Forged source | Exact Production ID + host + DB UUID binding |
| Replayed pairing challenge | Nonce + expiry + single-use |
| Stale discovery/readiness report | Expiry + signature |
| Modified readiness report | Signature over canonical JSON |
| Wrong License / account | Bind License ID + account in pair; SaaS eligibility scoped |
| MITM | Pinning; no TOFU; verify installer signatures |
| SSH host-key substitution | Display fingerprints; known_hosts strict; no auto-accept |
| Unsigned installer / mutable tag | Digest pin; refuse `latest` |
| Token leakage | Never log tokens; Phase 17 doesn’t burn; argv/env hygiene |
| Temporary cert leakage | Short TTL; 0600 store; revoke on abort |
| Command injection / path traversal / symlink escape | Exact-target path policy (Phase 14/16 patterns) |
| Destination path overwrite | Staging dirs + refuse unexpected paths |
| Secret in argv/logs/env | Stdin/files 0600; redaction |
| Broad cleanup | Explicit abort scope only |
| Cross-tenant pairing | Account/License binding checks |
| Unauthorized Stage inclusion | `selected_by_owner=false` default |
| Premature token burn / dest activation / source disrupt | Hard phase gates + static tests |
| SaaS payload relay | Sovereignty First allowlist; static gate |

## Malicious Root boundary (honest)

A malicious root on source or destination can always read local secrets, forge local state, and disrupt services. Phase 17 mitigations protect against **network attackers, confused operators, cross-tenant SaaS mistakes, and accidental destructive automation** — not against fully compromised root on either host. Remote attestation of honest root is out of scope.

## Static gates (implementation-time)

Forbid: payload transfer APIs, DNS mutate, token consume RPC, Production activate, source deactivate — in Phase 17 modules.
