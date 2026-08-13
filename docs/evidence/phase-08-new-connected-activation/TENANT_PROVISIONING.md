# TENANT_PROVISIONING — Phase 8

**Modules:** `src/tenant/identity.sh`, `src/tenant/secrets.sh`, `src/database/provision.sh`, `src/docker/provision.sh`

## Provisioning sequence

| Step | Function | Output | State |
|------|----------|--------|-------|
| Tenant identity | `soviez_tenant_identity_create` | `tenant_id` (UUID) | `tenant_identity_created` |
| Database | `soviez_database_provision` | `db_name` | `database_provisioned` |
| Container | `soviez_docker_provision_start` | container name | `container_started` |
| Secrets | `soviez_tenant_secret_write/read` | 0600 files | ongoing |

## Naming conventions

- Database: `soviez_<operation_id_sanitized>`
- Container: `soviez-web-<operation_id>` (or from state on resume)

## Test mode behavior

In `SOVIEZ_TEST_MODE=1`:
- Docker/database provision writes stub markers under `$SOVIEZ_ROOT/stubs/`
- No real PostgreSQL or container required
- Marker: `stubs/container-<op_id>.started` (verified in cleanup test)

## Secret storage

| Secret | Path pattern | Permissions |
|--------|--------------|-------------|
| `activation_key` | `tenants/<id>/secrets/activation_key` | 600 |
| `db_name` | tenant secrets | 600 |

Certified: `test_secret_handling.sh`

## Resume

On `--reattach`, tenant_id/db_name/container loaded from `state.json` or tenant secret store.

## Production (not certified here)

Real Docker + PostgreSQL provisioning code paths exist in modules; full infrastructure E2E deferred to owner environment.
