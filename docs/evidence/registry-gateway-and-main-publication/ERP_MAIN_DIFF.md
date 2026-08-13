# ERP_MAIN_DIFF — Soviez/soviez-erp Main Integration

## Status

**PENDING** — push not done.

## Publish scope (PP-04)

**Single file only:**

```
soviez.sh
```

## Wizard integrity

| Field | Value |
|-------|-------|
| File | `soviez.sh` |
| SHA256 | `4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841` |
| Parity partner | `soviez-deploy/soviez.sh` (must match byte-for-byte) |

## Must NOT appear in ERP main commit

- `venv/**`
- Unrelated `CHANGELOG.md` delta
- UI / module changes outside wizard
- `.DS_Store` or test artifacts

## Remote

| Field | Value |
|-------|-------|
| Remote | `origin` → `https://github.com/Soviez/soviez-erp.git` |
| Target branch | `main` |
| Pre-push main SHA | **PENDING** |
| Post-push main SHA | **PENDING** |

## Post-push checks

- [ ] `git diff --name-only <pre>..<post>` shows only `soviez.sh`
- [ ] SHA256 matches deploy wizard
- [ ] No secrets in commit

See `ERP_SCOPE_CLOSURE.md`, `POST_PUSH_VERIFICATION.md`.
