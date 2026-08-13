# Final acceptance criteria

## Engineering certification
| Result | Rule |
|--------|------|
| PASS | Baseline SHA valid; provenance complete; mandatory E2E green with real-runtime; security/sovereignty/SaaS/multi-tenant green; docs DOC_SYNC_PASS or WARNING; release checklist evaluated; eng owner sign-off; no unclassified blocking debt |
| WARNING | Non-blocking gaps (e.g. optional remotes unavailable) explicitly listed |
| BLOCKED | Any mandatory E2E fail; security fail; provenance incomplete; DOC_SYNC_BLOCKED; blocking debt open; baseline mismatch |

## Release readiness
READY / READY_WITH_OWNER_DECISIONS / NOT_READY — independent of eng PASS.

## Release authorization
NOT_AUTHORIZED / AUTHORIZED — never auto-set by eng PASS.

## 100%
Awarded only after Phase 25 eng PASS credits 0.5 **and** OD-P25-01 path allows; never by scope review.
