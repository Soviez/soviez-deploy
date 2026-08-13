# Sandbox Failure Analysis — Phase 17 Final Certification Closure

## Required wording

```text
The earlier sandbox-constrained tests/run_all.sh execution failed because
Docker-dependent suites could not access the Colima socket.
A later full-permission execution successfully accessed the required Docker
runtime and completed with:
run_all: PASS
The later execution supersedes the sandbox-constrained run for regression
certification purposes. The earlier result remains documented as an
environment-access limitation.
Phase 17 remained PARTIAL due to separately documented acceptance gaps.
```

## Root cause

Sandbox execution denies access to `unix:///Users/raafatagha/.colima/default/docker.sock`.
Docker-dependent suites (SFTP backup fixtures, reboot matrix, restore-test, Stage live
PostgreSQL, Phase 17 destination host containers, etc.) cannot start fixtures.

## Classification

**Environment-access limitation** — not a product defect in `src/migration/**`.

## Evidence preservation

- Earlier sandbox-constrained `tests/run_all.sh` result: **FAILED** (must not be rewritten as PASS).
- Later full-permission `tests/run_all.sh` result: authoritative for regression certification.
- Both results remain in `RUN_ALL_EXECUTION_HISTORY.md`.
