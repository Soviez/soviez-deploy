# CLI Reference

**Sources of truth:**  
- Modular platform: `src/cli/parse.sh` + `src/entrypoint.sh` → installed as `/usr/local/bin/soviez.sh`  
- Version: `0.24.6.1-platform-cli`

**Canonical invocation:** `soviez.sh ...` from any directory.

**Not supported:** `--merge-in` (never implemented).

## Core local commands

| Command | Purpose | Network |
|---------|---------|---------|
| `--help` | Usage | Offline |
| `--version` | Platform version, channel, artifact digest | Offline |
| `--list` | All Soviez-managed environments (Production + Stage) | Offline |
| `--stage-list` | Stage-only inventory | Offline |
| `--tune` / `--tune --dry-run` | Automatic resource sizing | Offline apply; online self-update may run first for mutating cmds |
| `--platform-install` | Install payload + PATH launcher | Local |

## Platform self-update

Connected **mutating** lifecycle commands check for a newer **signed** platform release, verify SHA256 (+ signature), activate atomically, then re-exec the original argv.

Read-only/local commands remain usable offline / during SaaS or Registry outage.

```text
Platform/security/compatibility update: NOT blocked by Technical Support expiry.
ERP product/image update: entitlement-gated.
```

## Global options

| Flag | Purpose |
|------|---------|
| `-h`, `--help` | Usage |
| `--confirm` / `--yes` / `-y` | Confirmation |
| `--dry-run` | Dry-run where supported |
| `--output PATH` | Export path |
| `--operation-id ID` | Select/resume operation |

## Modular — activation / update / Stage

| Command | Purpose |
|---------|---------|
| `--new` | Connected activation operation |
| `--reattach OP` | Reattach `--new` |
| `--update PROD --release ID` | Safe ERP product update |
| `--update-status\|reattach\|cancel\|retry\|recover\|rollback\|cleanup OP` | Update control |
| `--update-image-status\|cleanup` | Image retention |
| `--stage` | Create Stage |
| `--stage-list\|status\|start\|stop\|backup\|drop` | Stage lifecycle |
| `--stage-retention-*` | Retention |
| `--offline-request` / `--offline-import PATH` | Stage offline auth (with `--stage`) |

## Modular — SSL / operations

| Command | Purpose |
|---------|---------|
| `--ssl-status\|renew\|repair\|policy\|try-again\|abort\|reattach` | Certificates |
| `--operations` | List operations |
| `--operation-status\|reattach\|cancel\|retry\|recover\|logs\|reconcile` | Op engine |

## Modular — backup / restore / security / migration

See family docs: [BACKUP.md](BACKUP.md), [RESTORE.md](RESTORE.md), [SECURITY.md](SECURITY.md), [MIGRATION.md](MIGRATION.md), [TUNING.md](TUNING.md), [OFFLINE_UPDATES.md](OFFLINE_UPDATES.md).
