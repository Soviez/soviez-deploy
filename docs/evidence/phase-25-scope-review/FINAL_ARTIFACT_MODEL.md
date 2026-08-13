# Final artifact model

## Options
| Option | Artifact | Runtime change | When |
|--------|----------|----------------|------|
| **A** | Certify exact `0.24.0-phase24` @ `c0bb0e3e2130243387d58c11c153abd8506deaa9ecc77322cfbada077816b0b7` | None | Preferred if no packaging delta |
| **B** | Assemble `0.25.0-phase25` | Metadata/version only; no functional behavior change | If Phase 25 packaging/docs embedding requires version stamp |
| **C** | Explicit RC version | Packaging only | If owner wants RC channel distinct from phase tags |

## Recommendation
**Option A** — matches master plan (no versioning mandate), preserves Phase 24 security-certified SHA, avoids unnecessary rebuild risk.  
Choose B only if implementation must embed Phase 25 certification markers into the assembled installer header/version.

Do not implement during scope review.
