# MAIN_BRANCH_SHAS — Post-Publication Pin

## Status

**PENDING** — git push to remote main not completed for any repository in this mission.

## Target repositories

| Repository | Remote | Branch | Pre-push SHA | Post-push SHA |
|------------|--------|--------|--------------|---------------|
| soviez-sh | PENDING (PP-01) | `main` | PENDING | PENDING |
| Soviez/soviez-deploy | `origin` → `Soviez/soviez-deploy` | `main` | PENDING | PENDING |
| Soviez/soviez-erp | `origin` → `Soviez/soviez-erp` | `main` | PENDING | PENDING |
| soviez-saas | (project remote) | `main` | PENDING | PENDING |

## Compatibility pin (after push)

Record all four post-push SHAs here and in `CROSS_REPO_COMPATIBILITY.md` for live simulation baseline.

## Wizard SHA (local, pre-push)

Dual wizard byte identity (must survive push):

```
4e162df0e866341b6a3c41cab8b16a15aaf7ef3d535aebac274bfe8c922d5841
```

## Installer artifact SHA (local, pre-push)

```
60b7e320777df5ef95ba192247d3e5b22b34078c2dfb2b1d9fc9955caf7e24dc
```

## Update procedure

After each successful main push:

1. `git rev-parse main` on each repo
2. Fill post-push SHA column above
3. Run `POST_PUSH_VERIFICATION.md` checklist
4. Update `FINAL_REPORT.md` verdicts if all gates pass
