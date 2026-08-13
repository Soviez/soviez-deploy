# CORRECTED_SCOPE.md

## Title correction

| | Text |
|---|------|
| **Shorter plan title** | Traffic ownership transfer / Production cutover |
| **Corrected title** | **Phase 21 — Production Traffic Cutover, DNS Transition, Health Validation, and Immediate Rollback** |
| **Why rename** | Shorter title omits four binding deliverables: (1) **DNS transition** as a distinct gated step from nginx activation; (2) **health validation** on the public Production domain before traffic_owner commit; (3) **immediate rollback** window and unsafe-after-writes policy; (4) **Production traffic** specifically — not generic "cutover" which could mean container update or dashboard IP rebind. Phase 21 is the first phase authorized to mutate customer-facing Production routing while preserving Phase 20 commercial irreversibility. |

## Objective

After certified Phase 20 state (`migration_origin_grace` + `production_licensed_pre_cutover` + Phase 21 readiness PASS/WARNING), execute a **provider-neutral hybrid cutover (Option C)**: activate destination Production nginx route, switch authoritative Production DNS to destination, place source in maintenance/read-only during propagation, pass public health checks on destination, flip `traffic_owner=destination`, block source writes, enable selected integration activations, and maintain an **immediate rollback window** — stopping before source archive/purge (Phase 22).

## Inclusions

- Exact authorization / pair targeting + Phase 20 + Phase 21 readiness revalidation
- **Mandatory** cutover final sync (write freeze + DB/filestore delta) before public route
- Destination Production nginx route activation (ERP upstream enabled)
- Production TLS validation on destination
- Manual-first Production DNS transition instructions + verification (local mock/live adapters)
- Source state transitions: `cutover_freeze` → `cutover_maintenance`
- Public health and smoke tests on Production domain (destination)
- `traffic_owner=destination` commit after health PASS
- Source write block at commit boundary
- Incremental integration activation (mail, payment, webhooks) post-health
- Selected Stage **public** cutover (mandatory BLOCKED / optional WARNING)
- Rollback orchestration within default 30-minute window
- Automatic rollback trigger evaluation (advisory or enforced — owner decision)
- Operation-engine integration, idempotency, pause/recovery
- Signed cutover completion report + rollback audit trail
- Conflict matrix, security threat model, data egress audit

## Exclusions (later phases)

| Exclusion | Owner phase |
|-----------|-------------|
| Source archive, purge, deletion, long-term retention | **22** |
| Post-rollback reverse-migration automation (full) | **22** / Needs Action |
| SaaS traffic relay / proxy cutover | **never** |
| New payload full re-transfer (unless rollback reverse-migration) | **19** / exceptional |
| Token restore / commercial reversal after cutover | **exceptional admin** |
| Dashboard/SaaS UI cutover wizard | separate auth; frozen now |
| Automatic deletion of source backups | **22** |
| License Guard full epoch model (if not closed in 21) | **22** handoff risk |

## Target flow (Option C)

```text
select exact authorization + pair
→ revalidate Phase 20 + Phase 21 readiness (not expired, no drift)
→ optional cutover final sync (source read-only snapshot delta)
→ source: cutover_freeze (quiesce writes, keep serving)
→ destination: activate Production nginx route (internal verify)
→ destination: validate Production TLS
→ emit manual DNS instructions (Production → destination)
→ operator: authoritative DNS switch (OUT OF BAND — documented only)
→ verify DNS propagation observation (no secret provider creds in docs)
→ source: cutover_maintenance (maintenance page / read-only)
→ destination: public health + smoke PASS
→ COMMIT: traffic_owner=destination, source writes blocked, traffic_cutover_started=true
→ incremental: mail / payment / webhooks (post-health)
→ selected Stage public routes (mandatory/optional policy)
→ signed cutover completion report
→ rollback window open (default 30m)
→ STOP (no archive/purge)
```

## Binding future outcome (post-implementation banner)

```text
PHASE 20 AUTHORIZATION — VALID
CUTOVER FINAL SYNC — COMPLETE / SKIPPED
DESTINATION PRODUCTION ROUTE — ACTIVE
PRODUCTION TLS — VALID
PRODUCTION DNS — POINTS TO DESTINATION
SOURCE — CUTOVER_MAINTENANCE (WRITES BLOCKED)
PUBLIC HEALTH — PASS
TRAFFIC_OWNER — DESTINATION
INTEGRATIONS — ACTIVATED (INCREMENTAL)
SELECTED STAGES — PUBLIC (PASS / WARNING)
ROLLBACK WINDOW — OPEN / EXPIRED
READY FOR PHASE 22 ARCHIVE HANDOFF — PASS / WARNING / BLOCKED
```

## Sovereignty

No business payloads to SaaS. Cutover metadata and audit events only per `DATA_EGRESS_MODEL.md`. No SaaS traffic relay.
