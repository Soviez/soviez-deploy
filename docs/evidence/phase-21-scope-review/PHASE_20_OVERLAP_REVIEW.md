# PHASE_20_OVERLAP_REVIEW.md

**Date:** 2026-08-03  
**Peer:** Phase 20 — Atomic Migration Authorization, Token Consumption, License Rebind, and Destination Activation

## What Phase 20 owns (keep — already PASS)

- Migration Token consumed exactly once (commercial ledger authoritative).
- Destination permanent slot binding (`production_licensed_pre_cutover`).
- Source `migration_origin_grace` with traffic still on source.
- Destination internal Production-mode activation (`public_route=false`).
- Integration neutralization (mail, payments, webhooks, cron).
- Selected Stage identity rebind (internal; public routes disabled).
- Anti-split-brain: `traffic_owner=source`, `licensed_future_owner=destination`.
- Signed Phase 21 readiness report (`phase21_allowed=false` until Phase 21 impl).

## Phase 21 entry prerequisites (from Phase 20)

| Gate | Requirement |
|------|-------------|
| Authorization | Committed, idempotent, not expired |
| Token | `grant_remaining=0`, exactly one consumption |
| Slots | Exactly one permanent slot on destination |
| Source grace | Valid `migration_origin_grace` JSON + ledger row |
| Destination | Activation healthy internally; backup post-activation present |
| Readiness | Phase 21 readiness PASS or owner-accepted WARNING set |
| DNS | `production_dns_changed=false` |
| Cutover | `traffic_cutover_started=false` |

## What Phase 21 must extend (not redo)

| Phase 20 state | Phase 21 transition |
|----------------|---------------------|
| `production_licensed_pre_cutover` | → `production_licensed_active` (after health + traffic_owner) |
| `migration_origin_grace` | → `cutover_freeze` → `cutover_maintenance` |
| `public_route=false` | → `public_route=true` on destination only after health PASS |
| `traffic_owner=source` | → `traffic_owner=destination` at commit boundary |
| Integration neutralization | → incremental activation post-health |

## What Phase 21 must not invalidate silently

- Token consumption is **irreversible** — rollback after cutover is DNS/traffic policy, not token restore.
- Destination permanent binding survives cutover; rollback may require reverse-migration (Needs Action).
- Stage rebind identities from Phase 20 remain; Phase 21 adds **public routing** for selected Stages only.

## Phase 20 exclusions confirmed for Phase 21

Phase 20 explicitly stopped before DNS/routing cutover. Phase 21 is the **first authorized phase** for:

- Production DNS mutation instructions and verification.
- Public destination ERP on Production domain.
- Source Production maintenance/read-only serving.
- `traffic_cutover_started=true`.

## Revalidation at Phase 21 preflight

Phase 20 readiness TTL (recommended 24h) requires revalidation before cutover start. Drift on identity, digest, pair, public route, or split-brain → BLOCKED.

## License Guard gap (cross-cutting)

Phase 20 binding JSON includes grace/pre-cutover semantics locally. ERP `local_license_guard` lacks first-class recognition — Phase 21 implementation must coordinate LG policy or accept LG WARNING during cutover window (see `OWNER_DECISIONS.md` OD-38…OD-42).
