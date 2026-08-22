# User / Operator Documentation

**Audience:** server administrators, customers, consultants, DevOps, support.  
**Product contract:** [../SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md)  
**Platform build:** `0.24.6.4-platform-cli`

Start here if you operate Soviez hosts. You do not need to read source code.

## Core

| Doc | Topic |
|-----|-------|
| [PRODUCT_OVERVIEW.md](PRODUCT_OVERVIEW.md) | What Soviez.sh is |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Prerequisites |
| [QUICK_START.md](QUICK_START.md) | Fast path |
| [INSTALLATION.md](INSTALLATION.md) | Host install |
| [INITIALIZATION.md](INITIALIZATION.md) | `--init` host preparation |
| [NEW_PRODUCTION.md](NEW_PRODUCTION.md) | `--new` Production |
| [CLI_REFERENCE.md](CLI_REFERENCE.md) | Full CLI |

## Licensing & connectivity

| Doc | Topic |
|-----|-------|
| [ACTIVATION.md](ACTIVATION.md) | Activation flows |
| [LICENSING.md](LICENSING.md) | License / Device / Slot |
| [SUPPORT_AND_EXPIRY.md](SUPPORT_AND_EXPIRY.md) | Support expiry behavior |
| [OFFLINE_MODE.md](OFFLINE_MODE.md) | Air-gapped operation |
| [OFFLINE_UPDATES.md](OFFLINE_UPDATES.md) | Signed offline bundles |

## Network & edge

| Doc | Topic |
|-----|-------|
| [DOMAIN_AND_TLS.md](DOMAIN_AND_TLS.md) | Domains & certificates |
| [NETWORKING.md](NETWORKING.md) | Topology & ports |
| [WEBSOCKET_AND_LONGPOLLING.md](WEBSOCKET_AND_LONGPOLLING.md) | Realtime / WS |
| [CLOUDFLARE.md](CLOUDFLARE.md) | Cloudflare edge mode |
| [FIREWALL.md](FIREWALL.md) | Firewall |
| [SSH.md](SSH.md) | SSH hardening |

## Environments & lifecycle

| Doc | Topic |
|-----|-------|
| [STAGE_ENVIRONMENTS.md](STAGE_ENVIRONMENTS.md) | Stage |
| [UPDATES.md](UPDATES.md) | Connected updates |
| [BACKUP.md](BACKUP.md) | Backup |
| [RESTORE.md](RESTORE.md) | Restore & quarantine |
| [DISASTER_RECOVERY.md](DISASTER_RECOVERY.md) | DR terminology |
| [MIGRATION.md](MIGRATION.md) | Soviez↔Soviez migration |

## Security & database

| Doc | Topic |
|-----|-------|
| [SECURITY.md](SECURITY.md) | Security overview |
| [DATABASE.md](DATABASE.md) | PostgreSQL |
| [PDF_REPORTING.md](PDF_REPORTING.md) | wkhtmltopdf / reports |

## Operations

| Doc | Topic |
|-----|-------|
| [STATUS_AND_DIAGNOSTICS.md](STATUS_AND_DIAGNOSTICS.md) | Status |
| [RECOVERY.md](RECOVERY.md) | Recovery |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Symptom guide |
| [COMMON_ERRORS.md](COMMON_ERRORS.md) | Error patterns |
| [CONFIGURATION_REFERENCE.md](CONFIGURATION_REFERENCE.md) | Config files |
| [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md) | Env vars |
| [FAQ.md](FAQ.md) | FAQ |
| [GLOSSARY.md](GLOSSARY.md) | Terms |

## Important CLI note

There is **no** public `--merge-in` command. Migration uses `--migration-*` only.

**Customer CLI:** `soviez.sh` on PATH (`/usr/local/bin/soviez.sh`). Do not invoke from repository `dist/` or checkout paths.

**`--init`:** Implemented on the public PATH CLI (`0.24.6.4`). Live certification pending — see [INITIALIZATION.md](INITIALIZATION.md) and [IMPLEMENTATION_STATUS_MATRIX.md](../IMPLEMENTATION_STATUS_MATRIX.md).
