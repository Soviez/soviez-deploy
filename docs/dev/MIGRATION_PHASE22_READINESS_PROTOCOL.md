# Migration Phase 22 Readiness Protocol

## Purpose

Produce a signed **post-cutover** readiness report assessing whether a future Phase 22 source archive/purge operation *could* be authorized. Phase 21 **never** executes archive or purge — this module reports only.

## Distinction from Phase 21 pre-cutover readiness

| Report | Module | When |
|--------|--------|------|
| Pre-cutover | `phase21_readiness/engine.sh` | After Phase 20 activation; before cutover authorized |
| Post-cutover | `phase22_readiness/engine.sh` | After cutover complete; before Phase 22 authorization |

## Operation

`soviez_migration_phase22_readiness <authorization-id>`

Invoked automatically at end of `soviez_migration_cutover_start`; output written to cutover op dir as `phase22_readiness.json`.

`soviez_migration_phase22_readiness_show <report-id>` — enforces TTL (`SOVIEZ_MIG_P22_READINESS_TTL_SECONDS`, default 86400).

## Blockers (→ BLOCKED)

- `traffic_owner_not_destination`

## Warnings (→ WARNING)

- `source_not_in_maintenance` (expected state: `cutover_maintenance`)

## Pass (→ PASS)

Destination owns traffic; source in maintenance; no archive/purge flags set.

## Report schema

`soviez.migration_phase22_readiness.v1`:

```text
readiness_status: PASS | WARNING | BLOCKED
archives_source: false          # always false in Phase 21
purges_source: false             # always false in Phase 21
blockers: []
warnings: []
expires_at: created + TTL
```

## Phase 22 authorization

`phase22_allowed` remains **false** on cutover completion artifacts until separate Phase 22 scope authorizes archive/purge execution.
