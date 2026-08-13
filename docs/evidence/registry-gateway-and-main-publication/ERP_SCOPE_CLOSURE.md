# ERP_SCOPE_CLOSURE — PP-04

## Verdict

**READY** (discipline documented; push **PENDING**)

## Blocker

| ID | Description | Status |
|----|-------------|--------|
| PP-04 | ERP publish must be path-scoped to `soviez.sh` only | **CLOSED by policy** |

## Publish rule

**Soviez/soviez-erp** — commit and push **only**:

```
soviez.sh
```

## Must NOT publish with this cycle

| Path / pattern | Reason |
|----------------|--------|
| `venv/**` | Local Python environment |
| `CHANGELOG.md` (unrelated delta) | Partner Subledger / unrelated releases |
| UI architecture / AR_FH evidence | Separate workstreams |
| `.DS_Store` | OS metadata |
| Any module outside wizard | Out of scope |

## Dual wizard parity requirement

Published `soviez.sh` must remain byte-identical to `soviez-deploy/soviez.sh`.

| File | SHA256 |
|------|--------|
| `Soviez ERP/soviez.sh` | `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841` |
| `soviez-deploy/soviez.sh` | `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841` |

## ERP remote

| Field | Value |
|-------|-------|
| Remote | `origin` → `https://github.com/Soviez/soviez-erp.git` |
| Target branch | `main` |

## Post-push verification

Confirm ERP main commit touches only `soviez.sh`: **PENDING** (`ERP_MAIN_DIFF.md`, `POST_PUSH_VERIFICATION.md`)
