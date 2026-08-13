# Security Threat Model — Phase 16 (Proposed)

## Assets

- Production database dumps and filestores  
- Backup encryption keys  
- Manifests (ownership, digests)  
- Temporary restore candidates  
- Remote destination credentials  

## Adversaries / boundaries

| Actor | Assumption |
|-------|------------|
| Malicious Root on host | Can read memory/disk; encryption is not DRM against Root — document honestly |
| Network attacker | Must not obtain plaintext backups in transit; TLS + encryption at rest for remote |
| Cross-tenant local user | Must not read other Production backups |
| Malicious imported archive | Treat as hostile until validated |
| Compromised SaaS | Must never receive backup payloads or keys |

## Threats and mitigations

| Threat | Mitigation |
|--------|------------|
| Path traversal / symlink escape | Canonicalize paths; refuse writes outside destination roots |
| Archive bomb | Size/inode preflight; extraction limits |
| Malicious tar entries | Allowlist members; no absolute paths |
| Backup overwrite / arbitrary write | Atomic publish; exclusive backup_id |
| Arbitrary file read via backup | Exact Production paths only; no operator path globbing |
| Command injection | No shell interpolation of names; argv arrays |
| Secrets in argv/logs | Key via fd/file; redact ops logs |
| Key leakage | 600/700 key files; never SaaS |
| Wrong destination ownership | Validate destination_id binding |
| Cross-tenant access | Inventory ACL by production_id |
| Backup ID guessing | Non-enumerable ids + authz checks |
| Restore to wrong Production | Exact ownership checks |
| Tampered manifest | Checksums + encryption auth tag |
| Stale backup replay | Schema + uuid + host affinity checks |
| Broad path deletion | Exact backup_id delete only |
| Insecure temp files | mktemp under restricted dirs; umask |
| World-readable backups | Enforce directory modes |
| Docker socket exposure | No widening socket access for backup |
| DB password exposure | Use existing secret channels; never print |
| Odoo web backup/restore | **Excluded** from product |

## Honest residual

Root-equivalent compromise defeats local confidentiality. Phase 16 optimizes for sovereignty, remote theft, and operational safety — not anti-Root DRM.
