# Corrected Scope — Phase 16

**Corrected title:** Phase 16 — Production Backup, Restore, Verification, and Recovery Management  

**Authorization:** **SCOPE REVIEW COMPLETE — IMPLEMENTATION NOT AUTHORIZED**  
**Progress credit:** none (remains **78%**)  
**Proposed weight:** **6** (Medium / Medium-High style matching Phase 15) — **uncredited**  
**Installer version:** remains `0.15.0-phase15`

## Why correction was required

Old plan (“Keep backup; add restore”) assumed a Production backup product already existed in soviez-sh. Inspection shows:

- No `--backup` / `--restore` CLI in soviez-sh  
- Stage `--stage-backup` is incomplete for live DB  
- Phase 13/15 paths are not a customer Production backup product  
- Legacy deploy has backup without restore  
- Odoo web backup/restore must be excluded  

## Corrected objective

Deliver a sovereign, ops-integrated **Production** backup and **candidate-first restore** product with verification, retention, optional remote destinations, and encryption — without SaaS backup hosting and without weakening License Guard.

## In scope (when later authorized)

1. Full backup as default restore-capable unit (DB `pg_dump -Fc` + filestore + manifest)  
2. Local destination required; optional owner-controlled remote (S3-compatible + SFTP recommended)  
3. Encryption: mandatory remote; local default-on pending OD-01  
4. Candidate-first same-host Production restore  
5. Verification levels (integrity / restore-test / privacy-preserving aggregates)  
6. Retention independent of Stage 14–60; pins pending OD-03/04  
7. Scheduling model (local)  
8. Phase 14 op types listed in `OPERATION_ENGINE_MODEL.md`  
9. Conflict matrix extension  
10. Capacity/performance gates  
11. CLI contract for backup/restore inventory  
12. Reuse of Phase 11 dump primitives and Phase 15 candidate/LG patterns  
13. English-only operator copy  

## Explicit exclusions

- Implementation in this review task  
- Crediting weight / changing progress from 78%  
- Regenerating `dist/soviez.sh` / bumping version  
- Incremental/WAL/PITR (defer)  
- Cross-host restore (Phase 17/migration)  
- Soviez-hosted backup vault / backup payload egress to SaaS  
- Odoo `/web/database/backup|restore` productization  
- Filestore-only as restore unit  
- Direct Production overwrite by default  
- New permanent License slot for restore candidates  
- Weakening License Guard  
- Treating Phase 15 recovery_set or Stage/retention archives as the Production product  
- SaaS UI changes / live deploys / commits  

## Dependencies

- Phase 14 Unified Operation Engine (PASS)  
- Phase 15 Safe Update candidate + LG temporary identity patterns (PASS)  
- Phase 11 PG dump/restore primitives (PASS)  
- Owner decisions OD-01…OD-18  

## Acceptance direction (future implementation)

Round-trip Full backup → integrity verify → candidate restore-test → same-host Production restore with rollback window — on lab tenant — without SaaS upload of backup data.

## Next allowed action

1. Owner answers `OWNER_DECISIONS.md`  
2. Owner explicitly authorizes Phase 16 **implementation**  
3. Only then modify `src/` / tests / assemble installer  
