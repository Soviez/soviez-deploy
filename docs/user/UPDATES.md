# Connected Updates

## Success means more than containers Up

Update success requires pre→change→post validation: entitlement, signed artifact, backup, candidate DB/addon update, security/network/PDF checks, switch, and health — not merely `docker ps` showing Up.

## Workflow

```text
prechecks
→ entitlement
→ backup
→ image/artifact acquisition (private Registry, short-lived credentials)
→ candidate
→ DB/addon update
→ security checks
→ network checks
→ PDF checks
→ switch
→ validation
```

APT package locks: **wait-or-fail** (no killall).

## Commands

```bash
soviez.sh --update <production-environment-id> --release <exact-release-id>
soviez.sh --update-status <operation-id>
soviez.sh --update-reattach <operation-id>
soviez.sh --update-cancel|retry|recover|rollback <operation-id>
soviez.sh --update-cleanup <operation-id> --confirm
soviez.sh --security-update-check
```

## Exact target

Updates require an **exact** signed release (`--release`). No floating "latest" for Production safety.

## Rollback

Safety window (default 24h via `SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS`) supports operator rollback. Rollback never restores PostgreSQL SUPERUSER privileges.
