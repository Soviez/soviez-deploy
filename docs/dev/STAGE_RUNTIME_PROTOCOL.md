# Stage Runtime Protocol (Phase 11)

**Status:** Implemented — PASS  
**Assembler version:** `0.12.0-phase12` (Phase 11 Stage contracts preserved; Phase 12 SSL CLI additive)  
**Exit class:** `SOVIEZ_ERR_STAGE=20` with structured `denial_code` JSON on stderr

---

## 1. CLI contracts

| Command | Purpose | Gated? |
|---------|---------|--------|
| `soviez.sh --stage [--stage-id ID] [--stage-domain FQDN] [--production-tenant T] [--reattach OP]` | Create Stage from managed Production | Yes |
| `soviez.sh --ssl-status [ENV]` | Local certificate health | Yes |
| `soviez.sh --ssl-renew ENV` | Force/manual renewal | Yes |
| `soviez.sh --ssl-repair ENV` | Repair (never stops ERP) | Yes |
| `soviez.sh --ssl-reattach OP` | Resume SSL operation | Yes |
| `soviez.sh --ssl-policy ENV [MODE]` | View/set renewal mode | Yes |
| `soviez.sh --stage-list` | List inventory | No |
| `soviez.sh --stage-status <id>` | Print identity JSON | No |
| `soviez.sh --stage-start <id>` | Start container | No |
| `soviez.sh --stage-stop <id>` | Stop container | No |
| `soviez.sh --stage-backup <id>` | Tar Stage backup + sha256 | No |
| `soviez.sh --stage-drop <id>` | Destroy Stage (confirm) | No |
| `soviez.sh --stage-reattach <op-id>` | Resume create SM | Resume prior auth |
| `soviez.sh --stage-retention-status [id]` | Local retention deadlines/countdown | No |
| `soviez.sh --stage-retention-extend <id> --days <total>` | Set total lifetime from original creation (max 60) | No |
| `soviez.sh --stage-retention-run/retry <id>` | Due deletion / recovery retry with confirmation | No |
| `soviez.sh --stage-retention-reattach <op-id>` | Resume durable retention deletion | No |
| `soviez.sh --stage --offline-request` | Export `soviez.stage-offline-request.v1` | Prep |
| `soviez.sh --stage --offline-import <package>` | Verify package + create offline | Package gated |

Flags (create): `--stage-id`, `--stage-domain`, `--production-tenant`, `--domain` (alias), `--offline-import PATH`, release/tooling digests via env when testing.

Live Postgres certification uses `SOVIEZ_STAGE_USE_LIVE_PG=1` (actual `pg_dump -Fc` / `pg_restore`). Durable worker: `SOVIEZ_STAGE_DURABLE_WORKER=1`. Test-only pause: `SOVIEZ_STAGE_PAUSE_AT=<state>`.

---

## 2. Inventory schema (`/var/soviez/stages`)

Production layout (test mode remaps under `$SOVIEZ_ROOT`):

```
/var/soviez/stages/
  index.json
  consumption.jsonl          # offline ticket ledger (helper)
  <stage_id>/
    identity.json
    origin-certificate.json
    filestore/
    config/
    secrets/
/var/soviez/ops/stage/<op_id>/
  state.json
  snapshots/
    db.dump
    db.dump.sha256
    filestore/
    filestore.sha256
  auth/
    ticket.token
    keys.json
/usr/local/lib/soviez/stage-operation-helper/soviez-stage-helper
```

### `identity.json` fields

`stage_id`, `parent_production_tenant_id`, `license_id`, `production_fingerprint`, `source_database_uuid`, `stage_database_uuid`, `stage_db_name`, `stage_container`, `stage_mac`, `stage_network`, `stage_domain`, `parent_production_domain`, `stage_filestore_path`, `stage_config_path`, `stage_secrets_path`, `release_digest`, `tooling_digest`, `operation_id`, `authorization_id`, `origin_certificate_path`, `lifecycle_status`, `health_state`, `retention_created_at`, `retention_expires_at`, `created_at`.

### `index.json`

```json
{"stages":[{"stage_id":"stagea","stage_domain":"stagea.example.com"}]}
```

Atomic write via temp + `mv`; directories mode `700` / secrets `700`.

---

## 3. Operation states (`SOVIEZ_STAGE_STATES`)

Ordered happy-path (from `src/stage/state_machine.sh`):

1. `created`
2. `preflight`
3. `production_selected`
4. `identity_reserved`
5. `resource_admission`
6. `waiting_for_connection_consent` *(optional branch)*
7. `device_authorized`
8. `entitlement_checked`
9. `operation_authorized`
10. `tooling_authorized`
11. `tooling_pulled`
12. `ticket_verified`
13. `snapshot_preparing`
14. `database_snapshot_created`
15. `filestore_snapshot_created`
16. `database_restoring`
17. `filestore_restoring`
18. `stage_runtime_created`
19. `neutralization_running`
20. `neutralization_validated`
21. `authorization_consumed`
22. `domain_pending`
23. `ssl_pending`
24. `runtime_validating`
25. `origin_certificate_issued`
26. `remote_completion_pending`
27. `completed`

Terminal / recovery: `canceled`, `failed_retryable`, `recovery_required`, `failed_terminal`.

Illegal transitions die with `SOVIEZ_ERR_STATE`. Resume uses `soviez_stage_sm_should_run` index comparison.

---

## 4. Naming

| Kind | Pattern |
|------|---------|
| Stage ID | `^[a-z0-9][a-z0-9_-]{1,62}$` (lowercased/sanitized) |
| Domain | normalized FQDN; unique across inventory |
| DB | `stage_<id_with_underscores>` |
| Container | `soviez-stage-<id>` |
| Network | `soviez-net-stage-<id>` |
| MAC | `02:xx:xx:xx:xx:xx` |

Conflicts → `STAGE_ID_CONFLICT`, `STAGE_DOMAIN_CONFLICT`, `STAGE_DB_CONFLICT`, `STAGE_CONTAINER_CONFLICT`, `STAGE_MAC_CONFLICT`.

---

## 5. Paths (env overrides)

| Variable | Default (prod) | Test mode |
|----------|----------------|-----------|
| `SOVIEZ_STAGES_DIR` | `/var/soviez/stages` | `$SOVIEZ_ROOT/stages` |
| `SOVIEZ_STAGE_OPS_DIR` | `/var/soviez/ops/stage` | `$SOVIEZ_ROOT/ops/stage` |
| `SOVIEZ_STAGE_HELPER_BIN` | `/usr/local/lib/soviez/stage-operation-helper/soviez-stage-helper` | resolved from repo |
| `SOVIEZ_STAGE_TOOLING_CACHE` | `/var/soviez/cache/stage-tooling` | `$SOVIEZ_ROOT/cache/stage-tooling` |
| `SOVIEZ_STAGE_LEDGER` | `/var/soviez/stages/consumption.jsonl` | under test root |

---

## 6. Helper invocation

Required binary/CLI (Node TS helper from Phase 10.5):

```
soviez-stage-helper verify --ticket … --keys … --expect … --ledger …
soviez-stage-helper neutralize --claims … --controls … --cert-out …
```

Installer resolves via `SOVIEZ_STAGE_HELPER_BIN` or `services/stage-operation-helper/dist/cli.js`. Missing helper → `TOOLING_UNAVAILABLE`. Failed verify → `TICKET_INVALID`. Failed neutralize → `NEUTRALIZATION_FAILED`.

**Bash alone cannot certify.**

---

## 7. Denial codes (`SOVIEZ_STAGE_DENIAL_CODES`)

`NO_MANAGED_PRODUCTION`, `PRODUCTION_SELECTION_REQUIRED`, `PRODUCTION_UNHEALTHY`, `PRODUCTION_IDENTITY_MISMATCH`, `LICENSE_BINDING_MISSING`, `DEVICE_AUTH_REQUIRED`, `DEVICE_REVOKED`, `STAGE_ENTITLEMENT_REQUIRED`, `STAGE_ENTITLEMENT_EXPIRED`, `RESOURCE_ADMISSION_FAILED`, `INSUFFICIENT_DISK`, `INSUFFICIENT_MEMORY`, `STAGE_ID_CONFLICT`, `STAGE_DOMAIN_CONFLICT`, `STAGE_DB_CONFLICT`, `STAGE_CONTAINER_CONFLICT`, `STAGE_MAC_CONFLICT`, `OPERATION_AUTHORIZATION_FAILED`, `TICKET_INVALID`, `TICKET_EXPIRED`, `TICKET_BINDING_MISMATCH`, `TOOLING_UNAVAILABLE`, `TOOLING_DIGEST_MISMATCH`, `SNAPSHOT_FAILED`, `DATABASE_RESTORE_FAILED`, `FILESTORE_CLONE_FAILED`, `STAGE_RUNTIME_FAILED`, `NEUTRALIZATION_FAILED`, `DNS_VALIDATION_FAILED`, `SSL_ISSUANCE_FAILED`, `ORIGIN_CERTIFICATE_FAILED`, `REMOTE_COMPLETION_PENDING`, `RECOVERY_REQUIRED`, `DESTRUCTIVE_CONFIRMATION_REQUIRED`.

Protocol contract is the code — not free-text messages. Emit:

```json
{"ok":false,"denial_code":"STAGE_ENTITLEMENT_EXPIRED","message":"…"}
```

---

## 8. Cleanup boundaries

| Action | Touches |
|--------|---------|
| Op failure | Op dir snapshots/temp only (safe leave for resume) |
| `--stage-drop` | Named Stage dir, Stage DB (test fixture / Stage DB), Stage container, Stage network |
| Never | Production container/DB/filestore; other Stages; global Docker prune |

Drop confirmation: interactive type-back or `SOVIEZ_STAGE_DROP_CONFIRM=<stage_id>`.

---

## 9. Retention integration (Phase 13)

Upon Stage creation, retention initializes local `retention.json` from immutable identity `created_at`: default 14 calendar days, maximum 60 calendar days, and an English neutralization-banner countdown. `--days` is total lifetime, not an increment. Retention is separate from Stage License/ticket entitlement.

The local scan performs final backup verification and Safe Shield before deleting only selected Stage resources. Uncertain ownership, backup failure, or partial cleanup fails closed to Needs Action/recovery-required; retry and reattach use durable deletion-step records. See `STAGE_RETENTION_PROTOCOL.md` and `STAGE_SAFE_SHIELD_PROTOCOL.md`.
