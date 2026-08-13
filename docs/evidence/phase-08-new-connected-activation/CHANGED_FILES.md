# CHANGED_FILES — Phase 8

## Created (soviez-sh — installer)

### Source modules (`src/`)

- `src/00-header.sh`, `src/version.sh`
- `src/core/errors.sh`, `logging.sh`, `redact.sh`, `json.sh`, `paths.sh`, `preflight.sh`
- `src/auth/device_keys.sh`, `signing.sh`, `device_client.sh`
- `src/api/http.sh`, `slots_client.sh`, `registry_client.sh`
- `src/registry/manifest_verify.sh`, `pull_client.sh`
- `src/tenant/identity.sh`, `secrets.sh`
- `src/docker/labels.sh`, `provision.sh`
- `src/database/provision.sh`
- `src/nginx/render.sh`
- `src/ssl/local_ca.sh`, `validate.sh`, `letsencrypt.sh`
- `src/license/fingerprint.sh`, `choice.sh`, `activate_orm.sh`, `ack.sh`
- `src/ui/dashboard.sh`, `consent.sh`
- `src/operations/state_machine.sh`, `engine.sh`, `systemd_unit.sh`
- `src/cli/parse.sh`
- `src/commands/new.sh`, `reattach.sh`
- `src/entrypoint.sh`

### Build & artifact

- `build/assemble.sh`
- `dist/soviez.sh` (generated)
- `dist/soviez.sh.sha256` (generated)
- `VERSION` — `0.8.0-phase8`

### Schemas

- `schemas/new_operation_state.schema.json`

### Tests

- `tests/run_all.sh`
- `tests/helpers/assert.sh`, `integration_env.sh`, `odoo_activate_stub.sh`
- `tests/unit/test_digest.sh`, `test_domain_ssl.sh`, `test_redact.sh`, `test_secret_handling.sh`, `test_signing.sh`, `test_state_machine.sh`
- `tests/integration/mock_saas_server.py`
- `tests/integration/test_new_automatic_path.sh`, `test_new_manual_path.sh`, `test_disconnect_resume.sh`, `test_cleanup_boundaries.sh`, `test_ssl_local_ca.sh`
- `tests/integration/test_guard_license_tools.py`

### Documentation

- `docs/ai/NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md`
- `docs/dev/NEW_COMMAND_PROTOCOL.md`
- `docs/user/INSTALLATION.md`
- `docs/evidence/phase-08-new-connected-activation/**`

## Modified (soviez-sh — docs append Phase 8)

- `docs/ai/CURRENT_STATE.md`
- `docs/ai/DECISION_LOG.md`
- `docs/ai/MASTER_IMPLEMENTATION_PLAN.md`
- `docs/ai/SOVEREIGNTY_FIRST_CONSTITUTION.md`
- `docs/ai/DATA_EGRESS_CONTRACT.md`
- `docs/ai/DEVICE_AUTHORIZATION_MODEL.md`
- `docs/ai/LICENSE_SLOT_RESERVATION_MODEL.md`
- `docs/ai/PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`
- `docs/dev/DEVICE_AUTHORIZATION_PROTOCOL.md`
- `docs/dev/LICENSE_SLOT_RESERVATION_PROTOCOL.md`
- `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`
- `docs/user/LICENSE_ACTIVATION.md`
- `docs/user/WHEN_SOVIEZ_CONNECTS_ONLINE.md`
- `docs/user/PRIVACY_AND_SOVEREIGNTY.md`
- `PROJECT_STATE.md`

## Explicitly NOT changed

- `Soviez ERP/addons/local_license_guard/**` — read-only fingerprint cert only
- `soviez-saas/**` — Phase 5–7 APIs consumed as-is; no new migrations
- Live Supabase / production deploy
- Docker Hub visibility / cutover

## No commit

Per phase gate: documentation and evidence only; no git commit in this session.
