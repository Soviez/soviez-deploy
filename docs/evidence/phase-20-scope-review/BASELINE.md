# BASELINE.md — Phase 20 Scope Review

## Certified state (input)

| Item | Value |
|------|-------|
| Phase 16–19 | **PASS** |
| Progress | **95%** |
| Installer | `0.19.0-phase19` |
| Artifact SHA256 | `eb7f29235d352db6cfe47a0c065d3eaa81104047d80ab7e3ab351dd6f51c25fc` |
| Phase 11.5 | FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED |
| Phase 20 impl | **NOT AUTHORIZED** |
| Phase 21+ | **UNAUTHORIZED** |

## Dirty-state preservation

No runtime changes. Prior Phase 19 PARTIAL/FAIL logs remain under `/tmp/p19-auth-run-all-*` and phase-19 evidence. This review adds documentation only under `docs/evidence/phase-20-scope-review/`.

## Repositories

| Repo | Role |
|------|------|
| `soviez-sh` | Installer migration ops; Phase 17–19 gates; future Phase 20 CLI |
| `soviez-saas` | Commercial ledger, wallet migrate RPCs, entitlement resolver |
| `Soviez ERP` | `local_license_guard` HMAC / fingerprint / staging vs permanent bind |
| `soviez-deploy/soviez.sh` | Legacy reference only |

## Artifact check (review start)

```text
version: 0.19.0-phase19
SHA256: eb7f29235d352db6cfe47a0c065d3eaa81104047d80ab7e3ab351dd6f51c25fc
```

Must remain identical at review end.
