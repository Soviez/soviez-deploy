# Environment Variables (Operator)

Focus: public/configurable variables. Test/certification inject flags are **not** for production.

## Paths & endpoints

| Name | Default | Purpose |
|------|---------|---------|
| `SOVIEZ_ROOT` | (prod unset; test temp) | State root |
| `SOVIEZ_OPS_ROOT` | `/var/soviez/ops` | Operations |
| `SOVIEZ_DEVICE_DIR` | `/etc/soviez/device` | Device binding |
| `SOVIEZ_SECRETS_DIR` | `/etc/soviez/secrets` | Secrets |
| `SOVIEZ_TENANT_DIR` | `/var/soviez/tenant` | Tenant runtime |
| `SOVIEZ_SAAS_BASE_URL` | `https://app.soviez.com` | SaaS API |
| `SOVIEZ_REGISTRY_GATEWAY_URL` | `https://registry.soviez.com` | Registry gateway base URL (client) |
| `SOVIEZ_STAGES_DIR` | `/var/soviez/stages` | Stages |
| `SOVIEZ_TEST_MODE` | `0` | **Must be 0** on customer hosts |

## Secrets (prefer files)

| Name | Notes |
|------|-------|
| `SOVIEZ_DEVICE_CREDENTIAL` | Secret |
| `SOVIEZ_ACTIVATION_KEY` / `SOVIEZ_LICENSE_KEY` | Secret |
| `SOVIEZ_REGISTRY_PASSWORD` | Short-lived **client** pull credential from ticket exchange (not Hub PAT) |
| `SOVIEZ_BACKUP_PASSPHRASE` | Prefer `SOVIEZ_BACKUP_PASSPHRASE_FILE` |
| `SOVIEZ_PG_ADMIN_PASSWORD` / `SOVIEZ_DB_PASSWORD` | Secret |

## Postgres

| Name | Default |
|------|---------|
| `SOVIEZ_PG_ADMIN_USER` | `soviez_admin` |
| `SOVIEZ_PG_APP_USER` | `soviez_app` |
| `SOVIEZ_PG_HOST` | `127.0.0.1` |
| `SOVIEZ_PG_PORT` | `5432` |

## Safety windows & policy

| Name | Default | Purpose |
|------|---------|---------|
| `SOVIEZ_UPDATE_STRICT_SIG` | `1` | Require signatures |
| `SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS` | `24` | Rollback window |
| `SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS` | `24` | Restore rollback window |
| `SOVIEZ_EDGE_MODE` | `direct` | `direct` \| `cloudflare_aop` |
| `SOVIEZ_SSH_POLICY` | `staged` | SSH hardening |
| `SOVIEZ_S5_ENFORCE` | `0` | Force S5 gates in lab |
| `SOVIEZ_BACKUP_DISABLE_ENCRYPTION` | `0` | Weakens local backups |
| `SOVIEZ_LOG_LEVEL` | `info` | Logging |

## Forbidden on customer hosts / in this repository

Do **not** configure or document as client variables:

- `SOVIEZ_UPSTREAM_REGISTRY_USER` / `SOVIEZ_UPSTREAM_REGISTRY_TOKEN` (Gateway **server** Hub credentials)
- Gateway signing **private** keys / ticket issuer private keys
- Internal Gateway host secrets (`/etc/soviez-registry-gateway/…`)

## Forbidden in production

Do not set migration wipe/purge/relay flags (`SOVIEZ_MIG_SOURCE_PURGE`, SaaS payload relay, etc.). Gates fail closed.
