# TRUST_BOUNDARIES — Phase 10.5

| Boundary | Trusted for | Not trusted for |
|----------|-------------|-----------------|
| SaaS Stage Operation keys | Issuing tickets | Business data |
| Device PoP | Caller identity | Entitlement alone |
| Stage License entitlement | Gated op eligibility | Stopping existing Stages |
| stage-operation-helper | Local verify/consume/neutralize | Surviving Root replacement |
| Local consumption ledger | Best-effort one-use offline | Integrity under Root |
| Origin certificate file | Local evidence | Remote attestation / phone-home |
| Private registry tooling digest | Artifact integrity | Preventing redistribution |

**Tests:** _(parent fills)_
