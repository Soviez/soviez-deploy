# FINAL_REPORT — Freeze & Reconcile Gate 0.24.6.4

**Verdict:** PARTIAL

Moving-tree run_all completed (SIGNAL_ONLY_MOVING_TREE_RUN): OK=400 FAIL=9 exit=1. Reconciliation commits landed on `cert/0.24.6.4-platform-cli` with catalog ERP fixtures, frozen-tree guard, phase-25 evidence churn reverted, staging manifest branch URL corrected and re-signed. Full certification tree cleanliness blocked by intentional exclusion of run_all-generated untracked evidence under `docs/evidence/*` (not committed).

**Blockers:** Phase 25 final certification still PARTIAL in last run_all; full `CLEAN_FROZEN_CERTIFICATION_TREE` requires ignoring or relocating generated evidence dirs outside repo.

**Evidence:** docs/evidence/freeze-reconcile-0.24.6.4/
