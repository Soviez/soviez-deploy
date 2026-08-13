# SECURITY_ADVERSARY_MATRIX

| Adversary | Prevented? | Notes |
|-----------|------------|-------|
| Casual Bash entitlement flip | Yes | Helper cert required |
| Forged ticket without key | Yes | Signature verify |
| Expired entitlement create | Yes | Entitlement gate |
| Cross-production ticket | Fail closed | Bindings |
| Full Root replace helper | **Not preventable** | Disclosed residual — not DRM |
| AI-assisted Bash bypass | Raised bar | Still Root-bypassable |

