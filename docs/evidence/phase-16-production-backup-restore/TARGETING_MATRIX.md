# Targeting matrix
| Input | Backup | Restore |
|-------|--------|---------|
| Exact Production ID | ALLOW | ALLOW with matching backup |
| Missing / empty | DENY | DENY |
| Wildcard / all | DENY | DENY |
| Stage ID as Production | DENY | DENY |
| Wrong production_id on backup | — | DENY `RESTORE_WRONG_PRODUCTION` |
| Cross-host identity | — | DENY `RESTORE_HOST_IDENTITY_MISMATCH` |
