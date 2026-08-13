# Overlap With Phases 5–16 — Phase 17 Scope Review

Phase 17 must **reuse** certified foundations and **not** create a parallel migration control plane.

## Phase 5 — Device Authorization

| Reuse | Boundary |
|-------|----------|
| Device keypair, fingerprint, authorize/poll, request signing | Destination bootstrap may Device-Authorize a **temporary** host identity |
| | Phase 17 must not treat device auth as Production License activation |

## Phase 6 — License Slot identity

| Reuse | Boundary |
|-------|----------|
| Slot client + fingerprint model | Phase 17 destination must **not** bind a permanent sellable Production slot |
| | Temporary/non-sellable bootstrap identity only; permanent slot bind = Phase 21 |

## Phase 7 — Signed installer / Registry

| Reuse | Boundary |
|-------|----------|
| Manifest verify, digest pin, pull session, gateway tickets, op allowlist `migration_bootstrap` | Destination obtains **exact** signed installer/release; no mutable `latest` |
| | Image pull for readiness may be OD-gated; no Production runtime activation |

## Phase 8 — Activation (`--new`)

| Reuse | Boundary |
|-------|----------|
| State-machine pattern, preflight, tenant identity, secrets store | **Do not** run full `--new` as migrate bootstrap |
| | No customer DB creation; no permanent activation; abort must not leave sellable Production |

## Phase 11 — Stage origin identity

| Reuse | Boundary |
|-------|----------|
| Production enum, Stage inventory fields, retention metadata | Inventory only; `selected_by_owner=false` default |
| | No Stage transfer, retention extension, or silent inclusion |

## Phase 12 — Domain/SSL

| Reuse | Boundary |
|-------|----------|
| Readiness inspection, try-again/abort UX patterns | Inspect domain/cert/DNS **state** only |
| | No DNS mutation, challenge for migrate domain, maintenance landing (Phase **18**) |

## Phase 13 — Stage retention

| Reuse | Boundary |
|-------|----------|
| Retention deadlines visible in Stage discovery | Do not keep expired Stages alive because migration was discovered |

## Phase 14 — Unified Operation Engine

| Reuse | Boundary |
|-------|----------|
| Registry, locks, conflicts (including foreshadowed `migrate`), reattach/retry/recover, reboot recovery | Register Phase 17 op types listed in `OPERATION_ENGINE_MODEL.md` |
| | Do not confuse `src/ops/migration.sh` (schema remap) with host migration |

## Phase 15 — Safe Update candidate identity

| Reuse | Boundary |
|-------|----------|
| Temporary identity, exact-target, non-slot LG candidate pattern, offline signed packages | Candidate is **same-host**; cross-host migrate pair is a **new** object |
| | `SOVIEZ_MIGRATION_SECRET` ≠ Migration Token |

## Phase 16 — Backup / restore

| Reuse | Boundary |
|-------|----------|
| Verified Full backup capability, export/import package shape, host identity stamps, conflict with backup/restore | Discovery may run without new backup; readiness/transfer policy per OD |
| | Cross-host restore remains **denied** until later migration transfer phases; Phase 17 transfers **no** payloads |

## SaaS commercial (pre-phase foundation)

| Reuse | Boundary |
|-------|----------|
| `migration_token` entitlement resolve; begin/cancel/migrate session APIs | Phase 17: eligibility display only; `consumed=false` |
| | Burn/reserve irreversibly = Phase **20** (owner OD on soft reserve) |

## Explicit non-overlap (Phases 18–22)

| Phase | Content |
|-------|---------|
| 18 | Maintenance landing, signed DNS challenge, migrate domain/cert |
| 19 | Stream DB/filestore/addons/config; Stage selection transfer |
| 20 | Migration Token burn + License hardware rebind wire |
| 21 | Destination Production activation / certify |
| 22 | Source retain/deactivate/purge |

Phase 17 that implements any of the above is **scope violation**.
