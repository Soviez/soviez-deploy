# CLI Reference

**Sources of truth:**  
- Modular: `src/cli/parse.sh` + `src/entrypoint.sh` → `dist/soviez.sh` (`0.24.5.3-registry-gateway`)  
- Dual wizard: `Soviez ERP/soviez.sh` ≡ `soviez-deploy/soviez.sh`

**Public modular commands:** ~189 internal command names / ~234 flags.  
**Not supported:** `--merge-in` (never implemented).  
**Wizard-only:** `--init` (host bootstrap).

## Global options

| Flag | Purpose |
|------|---------|
| `-h`, `--help` | Usage |
| `--confirm` / `--yes` / `-y` | Confirmation |
| `--dry-run` | Dry-run where supported |
| `--output PATH` | Export path |
| `--operation-id ID` | Select/resume operation |

## Dual wizard (Production host)

| Command | Purpose |
|---------|---------|
| `--init` | Host bootstrap |
| `--new` | Create Production |

## Modular — activation / update / Stage

| Command | Purpose |
|---------|---------|
| `--new` | Connected activation operation |
| `--reattach OP` | Reattach `--new` |
| `--update PROD --release ID` | Safe update |
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

## Modular — backup / restore

| Command | Purpose |
|---------|---------|
| `--backup PROD` | Backup |
| `--backup-list\|show\|verify\|export\|import\|pin\|unpin\|delete` | Inventory |
| `--backup-destination-*` / `--backup-schedule-*` / `--backup-retention-*` | Destinations/schedules |
| `--restore PROD --backup ID` | Production restore |
| `--restore-test` / `--restore-as-stage` | Test / Stage restore |
| `--restore-status\|cancel\|retry\|recover\|rollback\|cleanup` | Restore ops |

## Modular — offline / security

| Command | Purpose |
|---------|---------|
| `--offline-bundle-inspect\|plan\|import` | Bundles |
| `--offline-update-apply\|status\|result-*` | Apply + receipts |
| `--offline-trust-inspect\|import` | Trust |
| `--security-status\|scan\|scan-db\|check\|harden\|report` | Security |
| `--security-quarantine-*` | Quarantine |
| `--security-update-check` / `--security-backup-check` | S5 gates |
| `--security-phase25-readiness` | Informational readiness only |

## Modular — migration (selected)

Full list is large (~80+ flags). Families:

- Discovery/bootstrap/pair/readiness: `--migration-discover`, `--migration-bootstrap-*`, `--migration-pair*`, `--migration-readiness*`
- Domain/DNS/landing/TLS/routing: `--migration-domain-*`, `--migration-dns-*`, `--migration-landing-*`, `--migration-tls-*`, `--migration-routing-*`
- Transfer: `--migration-transfer-*`, `--migration-presync*`
- Authorization/activation: `--migration-authorization-*`, `--migration-activate-destination`, `--migration-activation-*`
- Cutover: `--migration-cutover-*`, `--migration-traffic-owner-show`
- Archive/retirement: `--migration-source-archive-*`, `--migration-stabilization-*`, `--migration-rollback-window-*`
- Generic: `--migration-status\|reattach\|cancel\|retry\|recover`

## Parse quirks (operators)

- First `--stage` arm wins as Stage **create**; migration stage-select via a later `--stage` option arm is **dead** in current parser — use dedicated migration stage select commands.
- `--backup` is a command unless already in restore context, then it is the backup-id option.

## Exit domains (numeric)

| Code | Domain |
|------|--------|
| 1–9 | Generic/usage/preflight/state/api/auth/ssl/license/terminal |
| 20–22 | Stage / retention / ops |
| 23 | Update |
| 24 | Security **or** backup (collision — read symbolic code) |
| 25 | Restore **or** migration/offline |

Always prefer the symbolic `domain:CODE` in logs over the numeric exit alone.

## Examples

```bash
./dist/soviez.sh --help
./dist/soviez.sh --operations --active
./dist/soviez.sh --backup prod-1 --type full
./dist/soviez.sh --update prod-1 --release 18.0.x.exact
./dist/soviez.sh --security-quarantine-status
```
