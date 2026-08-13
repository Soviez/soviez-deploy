# REGRESSION_RESULTS.md — Phase 17 Final Certification Closure

## Sandbox-constrained result

**FAILED** — Colima socket inaccessible. See `SANDBOX_FAILURE_ANALYSIS.md` and `RUN_ALL_EXECUTION_HISTORY.md`. Not rewritten as PASS.

## Full-permission authoritative result

```text
run_all: PASS
```

Timestamp UTC `20260801T190334Z`. Log: `FULL_PERMISSION_RUN_ALL.log`.

## Why the later run supersedes the earlier run

The sandbox run could not access Docker. The full-permission run accessed Colima and completed all suites. The earlier result remains an environment-access limitation. Phase 17 PARTIAL acceptance gaps are separately closed in `PARTIAL_GAP_LEDGER.md`.
