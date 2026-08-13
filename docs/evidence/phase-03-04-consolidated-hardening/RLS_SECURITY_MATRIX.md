# RLS / security matrix

| Check | Result |
|-------|--------|
| Non-superuser authenticated insert transaction | DENIED |
| Non-superuser authenticated insert mapping | DENIED |
| FORCE ROW LEVEL SECURITY on commercial tables | Enabled in harness |
| Service-role dual-write paths | PASS |
| Duplicate sync idempotent | PASS |
| Duplicate reverse/dispute idempotent | PASS |

Portal responses omit commercial ledger metadata (shape tests).
