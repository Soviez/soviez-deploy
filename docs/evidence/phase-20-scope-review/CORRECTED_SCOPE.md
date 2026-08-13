# CORRECTED_SCOPE.md

## Title

**Phase 20 — Atomic Migration Authorization, Token Consumption, License Rebind, and Destination Activation**

## Objective

After a certified Phase 19 destination staging environment exists, perform the **irreversible commercial and identity transition**: consume Migration Token exactly once, create destination permanent Production binding, place source into `migration_origin_grace`, activate destination ERP as `production_licensed_pre_cutover` **without public traffic**, rebind selected Stages, enforce anti-split-brain, and emit a signed Phase 21 cutover-readiness report — **stopping before DNS/routing cutover**.

## Inclusions

- Exact Phase 19 readiness targeting + revalidation
- Migration Token eligibility recheck (provider-neutral)
- Atomic migration authorization transaction (SaaS ledger authoritative)
- Source/destination License binding transition (one License, one slot move)
- Destination Production identity + permanent slot binding
- Source `migration_origin_grace`
- Destination internal Production-mode activation (non-public)
- Destination internal technical validation
- Selected Stage identity rebind
- Anti-split-brain controls
- Operation-engine integration, idempotency, pause/recovery, compensation **before** cutover
- Offline/manual signed authorization package (honest limits)
- Provider-neutral SaaS ledger integration
- Final Phase 21 cutover-readiness report

## Exclusions (later phases)

| Exclusion | Owner phase |
|-----------|-------------|
| Production DNS mutation / domain routing / customer traffic cutover | **21** |
| Public destination ERP on Production domain / landing replacement | **21** |
| Source shutdown / archive / purge / deletion | **22** |
| Final post-cutover rollback routing | **21/22** |
| Final customer acceptance / long-term retention cleanup | **22/25** |
| Stage public routing | **21+** |
| Automatic deletion of source backups | **22** |
| Payload transfer (DB/filestore/addons) | **19** (already done) |
| Token purchase UX / SaaS UI changes | later / frozen UI now |

## Target flow

```text
select exact migration pair
→ load Phase 19 verified staging
→ revalidate identities / readiness / entitlement
→ create atomic migration authorization (precommit)
→ lock exact License + entitlement
→ SaaS commit: token consumed + destination binding + source grace authorized
→ apply destination binding locally
→ apply source grace locally
→ activate destination ERP production_licensed_pre_cutover (internal)
→ rebind selected Stages
→ validate anti-split-brain
→ preserve source traffic + rollback capability
→ produce Phase 21 cutover-readiness report
→ STOP (no DNS/routing cutover)
```

## Sovereignty

No business payloads to SaaS. Metadata-only egress per `DATA_EGRESS_MODEL.md`.
