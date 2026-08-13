# New Command Protocol (implementer)

**Protocol version:** `new-instance/v1`  
**Installer version:** `0.8.0-phase8` (see `VERSION`; SHA256 in `dist/soviez.sh.sha256`)  
**Operation kind:** `new`  
**Auth:** Phase 5 device signed requests on all SaaS mutating routes

No real secrets in this document.

---

## 1. CLI interface

### 1.1 Commands

| Command | Purpose |
|---------|---------|
| `soviez.sh --new [options]` | Start new connected activation operation |
| `soviez.sh --reattach <operation-id>` | Resume in-progress operation |

### 1.2 Options

| Flag | Values | Default | Notes |
|------|--------|---------|-------|
| `--domain DOMAIN` | FQDN | none | Triggers domain_pending → SSL → nginx render |
| `--activation METHOD` | `automatic\|manual` | `automatic` | Manual skips ORM activation |
| `--channel CHANNEL` | e.g. `stable` | `stable` | Registry release channel |
| `--operation-id ID` | UUID | auto-generated | Optional fixed operation id |

Parser: `src/cli/parse.sh`

### 1.3 Exit behavior

- Success: prints `operation_id` on stdout; final state in operation ledger.
- Failure: non-zero exit; state may be `failed_retryable` or `failed_terminal`.

---

## 2. Operation persistence

### 2.1 Paths (under `SOVIEZ_ROOT`)

| Path | Purpose |
|------|---------|
| `ops/operations/<id>/state.json` | Current operation state + metadata |
| `ops/operations/<id>/events.jsonl` | Append-only transition log |
| `ops/operations/<id>/lock` | Exclusive lock for single worker |
| `tenants/<tenant_id>/secrets/` | `0600` activation key and DB name |
| `/etc/soviez/device/` | Device keys (planned production paths) |

### 2.2 State schema

JSON Schema: `schemas/new_operation_state.schema.json`

Required fields: `operation_id`, `kind`, `state`, `created_at`, `updated_at`

Optional correlation: `slot_id`, `device_id`, `release_id`, `digest`, `image_ref`, `pull_session_id`, `fingerprint`, `domain`

---

## 3. State machine

Implementation: `src/operations/state_machine.sh`

### 3.1 States (29)

```
created, preflight, waiting_for_connection_consent,
device_authorization_pending, device_authorized, slot_reserved,
release_resolved, image_pull_authorized, image_pulled,
tenant_identity_created, database_provisioned, container_started,
domain_pending, waiting_for_dns, ssl_pending, instance_provisioned,
fingerprint_bound, waiting_for_activation_method, license_issued,
activation_pending, activated, manual_activation_pending,
validating, completed, completed_activation_pending,
canceled, failed_retryable, recovery_required, failed_terminal
```

### 3.2 Transition guards

`soviez_sm_should_run_step(state, step_name)` — idempotent resume: completed steps skipped on reattach.

`soviez_sm_assert_transition(from, to)` — rejects illegal transitions.

### 3.3 Terminal states

| State | Meaning |
|-------|---------|
| `completed` | Automatic path finished; ERP activated |
| `completed_activation_pending` | Manual path; user must activate via portal |
| `failed_terminal` | Unrecoverable without operator intervention |
| `canceled` | User or operator canceled |

---

## 4. Orchestration flow

Implementation: `src/commands/new.sh`

| Step | Module(s) | SaaS API |
|------|-----------|----------|
| Preflight | `core/preflight.sh` | — |
| Consent | `ui/consent.sh` | — |
| Device auth | `auth/device_client.sh` | `/api/installer-auth/device/*` |
| Slot reserve | `api/slots_client.sh` | `POST /api/installer/slots/reserve` |
| Release resolve | `api/registry_client.sh` | `POST /api/installer/registry/releases/resolve` |
| Manifest verify | `registry/manifest_verify.sh` | — (local Ed25519 verify) |
| Pull session | `api/registry_client.sh` | `POST /api/installer/registry/pull-sessions` |
| Image pull | `registry/pull_client.sh` | registry-gateway OCI v2 |
| Tenant identity | `tenant/identity.sh` | — |
| Database | `database/provision.sh` | — |
| Container | `docker/provision.sh` | — |
| Domain/SSL | `ssl/local_ca.sh`, `ssl/validate.sh`, `nginx/render.sh` | — |
| Instance provisioned | `api/slots_client.sh` | `POST .../instance-provisioned` |
| Fingerprint | `license/fingerprint.sh` | `POST .../bind-fingerprint` |
| Activation method | `license/choice.sh` | `POST .../activation-method` |
| Issue license | `api/slots_client.sh` | `POST .../issue-license` |
| ORM activate | `license/activate_orm.sh` | — (local docker exec) |
| Activation ack | `license/ack.sh` | `POST .../activation-ack` |

---

## 5. ORM activation protocol

Implementation: `src/license/activate_orm.sh`

### 5.1 Production path

```bash
# 1. Stage key inside container (stdin → file, mode 0600)
printf '%s' "$activation_key" | docker exec -i "$web_container" \
  bash -c "umask 077; cat > '/tmp/.soviez_activate_$$' && chmod 600 '/tmp/.soviez_activate_$$'"

# 2. Official ORM invocation via odoo shell
docker exec "$web_container" odoo shell -d "$db_name" --no-http <<EOF
from pathlib import Path
p = Path("/tmp/.soviez_activate_$$")
key = p.read_text(encoding="utf-8").strip()
p.write_text("", encoding="utf-8")
try: p.unlink()
except OSError: pass
env["soviez.license.mixin"].action_activate_soviez_license(key)
EOF

# 3. Remove staging file (best-effort)
docker exec "$web_container" rm -f "/tmp/.soviez_activate_$$"
```

### 5.2 Security invariants

| Invariant | Test |
|-----------|------|
| Key not in argv | `test_secret_handling.sh`, integration event audit |
| Key not in logs | `soviez_redact_text`; `assert_not_contains` on events.jsonl |
| Staging file 0600 | umask 077 + chmod 600 |
| Staging file deleted | overwrite + unlink in ORM script |
| Official method only | No direct SQL or ICP bypass |

### 5.3 Test substitutes

| Mode | Behavior |
|------|----------|
| `SOVIEZ_ODOO_STUB=<script>` | Stub receives stdin key; writes marker without key content |
| `SOVIEZ_TEST_MODE=1` | Writes `stubs/activation-<db>.invoked` marker (no key) |

Stub: `tests/helpers/odoo_activate_stub.sh`

---

## 6. Secret handling

| Secret | Storage | Transmission |
|--------|---------|--------------|
| Device private key | `/etc/soviez/device/` (planned) | Never |
| Device credential | Local secure store | Hashed server-side; PoP only |
| Activation key | `tenants/.../secrets/activation_key` mode 600 | Never in logs/argv |
| Registry pull password | Temp docker config dir | Deleted after pull |
| Pull ticket | In-memory during pull | Short-lived |

Redaction: `src/core/redact.sh`  
Tenant secrets: `src/tenant/secrets.sh`

---

## 7. Disconnect and resume

Implementation: `src/commands/reattach.sh`

1. Load operation by id.
2. Acquire lock (detect stale worker via heartbeat).
3. Re-enter `soviez_cmd_new_run` flow; `soviez_sm_should_run_step` skips completed steps.
4. Certified: `tests/integration/test_disconnect_resume.sh` — resume from `device_authorization_pending` → `completed`.

---

## 8. Domain and SSL

| Mode | Module | Notes |
|------|--------|-------|
| Local CA (test/dev) | `ssl/local_ca.sh` | Issues cert+key+ca; validated by `ssl/validate.sh` |
| Let's Encrypt (planned prod) | `ssl/letsencrypt.sh` | Present; production cutover Phase 12 |
| Nginx render | `nginx/render.sh` | Reverse proxy to container:8069 |

Certified: `tests/unit/test_domain_ssl.sh`, `tests/integration/test_ssl_local_ca.sh`

---

## 9. Test mode environment

| Variable | Purpose |
|----------|---------|
| `SOVIEZ_TEST_MODE=1` | Stub docker/DB; skip real infrastructure |
| `SOVIEZ_AUTO_CONSENT=1` | Skip interactive consent prompt |
| `SOVIEZ_ROOT` | Isolated temp operation root |
| `SOVIEZ_SAAS_BASE_URL` | Mock or real SaaS base |
| `SOVIEZ_REGISTRY_GATEWAY_URL` | Mock or real gateway |
| `SOVIEZ_ODOO_STUB` | ORM activation stub script |

Mock SaaS: `tests/integration/mock_saas_server.py`

---

## 10. Build artifact

```bash
bash build/assemble.sh
# → dist/soviez.sh (version from VERSION)
# → dist/soviez.sh.sha256
bash -n dist/soviez.sh
```

**Do not edit `dist/soviez.sh` directly.** Source of truth is `src/`.

Current version: `0.8.0-phase8`  
SHA256: see `dist/soviez.sh.sha256` (changes on rebuild)

---

## 11. SaaS API dependencies (unchanged from Phases 5–7)

| Phase | Routes consumed |
|-------|-------------------|
| 5 | `/api/installer-auth/device/start`, `/token`, `/decision` |
| 6 | `/api/installer/slots/reserve`, `/instance-provisioned`, `/activation-method`, `/bind-fingerprint`, `/issue-license`, `/activation-ack` |
| 7 | `/api/installer/registry/releases/resolve`, `/pull-sessions`, `/complete` |

All mutating routes require Phase 5 PoP headers. See respective protocol docs.

---

## 12. Guard boundary

`local_license_guard` is **read-only** for Phase 8.

Fingerprint format certified via `tests/integration/test_guard_license_tools.py`:
- `build_odoo_fingerprint` → `{64-hex}::{uuid}`
- `store_license_activation` callable with mock ICP
- Requires `SOVIEZ_MIGRATION_SECRET` env for module import (fail-closed guard behavior)

Does **not** replace full Odoo container ORM E2E.

---

## 13. Implementation references

| Path | Role |
|------|------|
| `src/commands/new.sh` | Main orchestration |
| `src/commands/reattach.sh` | Resume entry |
| `src/license/activate_orm.sh` | ORM activation |
| `src/operations/state_machine.sh` | State definitions |
| `src/operations/engine.sh` | Lock, transitions, persistence |
| `build/assemble.sh` | Module assembly |
| `tests/run_all.sh` | Full test runner |
| `schemas/new_operation_state.schema.json` | State JSON schema |

Model: `docs/ai/NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md`
