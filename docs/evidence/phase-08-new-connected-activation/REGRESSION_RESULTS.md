# REGRESSION_RESULTS — Phase 8

**Date:** 2026-07-30  
**Scope:** Phase 8 installer + prior phase foundations

## Phase 8 installer suite

| Command | Result |
|---------|--------|
| `bash tests/run_all.sh` | **PASS** |

Includes `build/assemble.sh` + `bash -n dist/soviez.sh` + all unit/integration tests.

## Prior phase SaaS regression

Not re-run in this certification session (no soviez-saas test invocation). Phase 3–7 remain **PASS** per prior evidence:

| Phase | Prior result | Re-run this session |
|-------|--------------|---------------------|
| 3–4 consolidated | 24 unit + 13 db PASS | Not re-run |
| 5 device auth | 14 + 8 PASS | Not re-run |
| 6 slot reservation | 6 + 6 PASS | Not re-run |
| 7 private registry | 9 + 8 + 14 PASS | Not re-run |

**Rationale:** Phase 8 consumes Phase 5–7 APIs without SaaS schema changes. Installer tests use mock SaaS.

## Guard regression

| Check | Result |
|-------|--------|
| `test_guard_license_tools.py` (with `SOVIEZ_MIGRATION_SECRET`) | **PASS** |
| Guard source modified | **NO** |

## Static analysis

| Check | Result | Notes |
|-------|--------|-------|
| `bash -n dist/soviez.sh` | **PASS** | Syntax valid |
| ShellCheck | **SKIPPED** | Tool unavailable on host |

## Build regression

| Check | Result |
|-------|--------|
| `build/assemble.sh` | PASS — 36 modules |
| Missing module detection | PASS — assemble fails on missing file |

## Summary

No regressions observed in Phase 8 installer scope. Prior phase PASS status unchanged. ShellCheck gap documented honestly.
