# TEST_PLAN.md

**Date:** 2026-08-02  
**Status:** Plan only — no tests executed; `tests/` not modified

## Unit / contract (future)

- Manifest schema round-trip; payload classification matrix  
- State machine transitions + freeze timeout auto-release  
- Conflict matrix cases for `migration_transfer_*`  
- Token invariants (`reserved/consumed` always false)  
- Staging isolation assertions (no slot / no public login)  
- Chunk resume after partial write; digest mismatch → BLOCKED  

## Security static gates (future)

- Scoped allow of dump/restore **only** in authorized transfer modules  
- Retain bans: SaaS payload relay, FTP, TOFU, token consume RPCs, Production cutover, public login enable  

## Integration / failure injection (future)

- Mid-stream kill → resume  
- Reboot during pre-sync / freeze / apply (`REBOOT_AND_RECOVERY_MODEL.md`)  
- Optional Stage fail → WARNING; mandatory → BLOCKED  
- Abort preserve vs exact-delete flag  

## Non-goals for Phase 19 tests

- Phase 20 token burn E2E  
- Phase 21 Production login certification  
- Live customer payload transfer in this scope-review task  

## Scope-review verification (this task)

- Evidence pack completeness (37 files)  
- Docs-only path; no `src/`/`dist/`/`VERSION` edits  
