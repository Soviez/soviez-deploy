# Security Threat Model

| Threat | Mitigation |
|--------|------------|
| Forged rollback-window closure | Signed receipt; exact cutover ID; owner confirm; readiness binding |
| Premature archive | Stabilization + health + owner gates |
| Wrong source / License / cutover | Exact IDs; Phase 21 readiness fingerprint; drift detection |
| Stale Phase 21 readiness | TTL + invalidate on drift |
| Archive of active writing source | Write-block proof; traffic-owner check |
| Archive tampering / substitution / checksum forgery | Signatures; independent checksums; pinned paths |
| Backup / cert / DNS snapshot deletion | Forbidden codes; static gates |
| Secret leakage / unencrypted archive | Encryption mandatory; no secrets in manifests/logs |
| Unauthorized host shutdown / provider API | Manual first; adapter gated; no terminate |
| Broad Docker/DB/FS cleanup | Hard ban; exact targeting only |
| Symlink / path escape / tar traversal / archive bomb | Path canon; hardened extract; size limits |
| Hidden source reactivation / second Production | License Guard archived state; slot=1 |
| Cross-tenant / cross-Stage archive | Exact environment + Stage IDs |
| Purge disguised as archive | Separate ops; `purge_authorized=false` |
| Automatic deletion after retention | No auto-delete in Phase 22 |
| Audit tamper / legal-hold bypass | Immutable receipts; hold checks |
| Admin privilege abuse / malicious Root | Typed confirms; non-TTY tokens; audit |
