# Recovery

## Principles

- Prefer `--*-recover` / `--*-reattach` / `--*-retry` on the owning operation
- Do not manually delete candidate containers mid-update without understanding rollback sets
- Untrusted restore recovery goes through quarantine promote/reject
- Apt lock timeouts: wait for other apt owners or schedule maintenance — do not kill apt

## Commands

```bash
soviez.sh --operation-recover <id>
soviez.sh --update-recover <id>
soviez.sh --restore-recover <id>
soviez.sh --migration-recover <id>
soviez.sh --ssl-repair <env>
```
