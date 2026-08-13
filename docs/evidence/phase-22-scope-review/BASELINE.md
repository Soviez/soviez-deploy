# Phase 22 Scope Review — Baseline

**Date:** 2026-08-04  
**Task:** Phase 22 scope review and correction ONLY — documentation / inspection  
**Primary repo:** `/Volumes/PortableSSD/soviez-project/soviez-sh`  
**Reference:** `soviez-saas`, `Soviez ERP`, legacy `soviez-deploy/soviez.sh`

## Certified state (unchanged by this review)

| Item | Value |
|------|-------|
| Phase 16–21 | PASS |
| Progress | **97%** (`96 + 1`) |
| Installer | `0.21.0-phase21` |
| Artifact SHA256 | `b95203dbb6073362cc1215272e6e837ee75cc366f78ac2c7d09150a554ec462d` |
| Phase 11.5 | FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED |
| Phase 22 implementation | **NOT AUTHORIZED** |
| Phase 23+ | **UNAUTHORIZED** |

## Hard bans for this task

- No runtime / CLI / `dist/soviez.sh` changes
- No SaaS / frozen UI changes
- No real rollback-window closure, archive, purge, License mutation, host stop, backup/certificate/DNS deletion
- No commit / push / merge / tag / deploy / publish / release
- No live customer / SaaS / DNS / infrastructure changes

## Dirty-state preservation

Working tree already dirty (untracked `.tmp.*`, prior evidence, etc.). This review adds only documentation under `docs/evidence/phase-22-scope-review/` and updates four state docs. No cleanup of unrelated dirt.

## Master-plan conflict noted

Current master-plan Phase 22 title packs **retain/archive/purge** together.  
Current Phase 23 is **Offline bundles**, not purge.  
This review **corrects Phase 22** to reversible archive + retirement readiness and **keeps purge out**, without silently reassigning Phase 23.
