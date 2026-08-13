# Extension Matrix
| Request | Result |
|---|---|
| 14 → 30 | Allowed; deadline = creation + 30 calendar days |
| 30 → 60 | Allowed; deadline = immutable maximum |
| 60 → 60 | Idempotent |
| 60 → 61 | Denied: `RETENTION_MAXIMUM_EXCEEDED` |
| 60 → 14 | Denied: `RETENTION_EXTENSION_REDUCES_DEADLINE` |
| Entitlement expired | Existing Stage extension/lifecycle remains available |

Confirmation is typed Stage ID or explicit `--yes` for extension.
