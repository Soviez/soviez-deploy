# SOURCE_AVAILABILITY_AND_CONSISTENCY.md

**Date:** 2026-08-02  
**Strategy context:** Option B (`MIGRATION_STRATEGY_OPTIONS.md`)

## Source role during Phase 19

- Source remains **ACTIVE** before, during (except short final freeze), and after Phase 19  
- No source License deactivation; no Production traffic cutover away from source  

## Consistency model

| Phase of transfer | Source writes | Consistency target |
|-------------------|---------------|--------------------|
| Pre-sync passes | Allowed | Best-effort filestore/object inventory; may lag |
| Final write freeze | App writes blocked (controller) | Point-in-time: `-Fc` DB + filestore delta under freeze |
| After freeze release | Allowed | Source continues; dest staging is a frozen apply of final pass |

## Controllers (distinct)

| Control | Meaning | Default Phase 19 |
|---------|---------|------------------|
| App write freeze | Block application mutating APIs/jobs | **Yes** (final pass only) |
| ERP process stop | Stop Odoo/ERP containers/services | **No** by default |
| PostgreSQL stop | Stop DB engine | **No** by default |
| Maintenance landing | Public mig/landing page | Phase 18 artifact; **≠** freeze |

## Failure / timeout

- Hard timeout on freeze (OD: 15m target) → **auto release** write freeze; mark transfer WARNING/BLOCKED per state machine  
- Never leave source permanently frozen on Abort/crash without recovery path (`REBOOT_AND_RECOVERY_MODEL.md`)

## Stages

- Only **explicitly selected** Stages participate  
- Expired Stages **always excluded**  
- Optional Stage failure → WARNING unless marked mandatory → BLOCKED  
