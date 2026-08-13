# Corrected Scope — Phase 14

**Title:** Unified Operation Engine Consolidation and Cross-Command Recovery  
**Authorization:** NOT AUTHORIZED for implementation  
**Progress credit:** none until future PASS

## 1. Unified operation schema

Canonical local JSON record (no secrets) for all long-running installer operations.

Required common fields:

| Field | Notes |
|-------|-------|
| `operation_id` | Stable UUID |
| `operation_type` / `kind` | e.g. `new`, `stage_create`, `ssl_renew`, `stage_retention_delete`, future `update`, `backup`, `restore`, `migrate` |
| `environment_id` | Exact Stage/Production/env id |
| `environment_type` | `production` \| `stage` \| `host` \| … |
| `parent_production_id` | When applicable |
| `license_id` | Exact License ID when applicable (not Device secrets) |
| `command` | Invoking CLI surface |
| `requested_action` | e.g. create, renew, delete, repair |
| `created_at` / `updated_at` / `started_at` / `completed_at` | UTC ISO |
| `current_state` / `previous_state` | Shared + command-specific |
| `current_checkpoint` | Opaque to shared layer; command-owned |
| `progress` | Optional structured progress |
| `worker_identity` / `controller_identity` | PID/unit/host markers |
| `lock_ownership` | Who holds exclusive locks |
| `heartbeat_at` | Stale detection |
| `retry_count` / `next_retry_at` | Shared retry bookkeeping |
| `cancellation_state` / `rollback_state` / `recovery_state` | Shared contracts |
| `failure_code` / `failure_classification` | Structured codes |
| `safe_log_path` / `artifact_paths` | Local paths only |
| `schema_version` / `engine_version` | Migration |

**Forbid:** passwords, private keys, Device credentials, registry tokens, customer business payloads.

## 2. Shared state-machine contract

Framework for `--new`, Stage create, SSL, retention, and future update/backup/migration.

Shared lifecycle states (minimum):

`created` · `queued` · `running` · `waiting` · `retry_scheduled` · `cancel_requested` · `rollback_running` · `recovery_required` · `completed` · `canceled` · `failed_retryable` · `failed_terminal`

Command-specific states remain first-class (do not flatten Stage/SSL/`--new` semantics).

## 3. Global operation registry

Host-local registry (filesystem or indexed JSON; no SaaS required) that can:

- list all operations
- filter by environment / command type / active|retry|recovery
- reconcile orphans
- prevent duplicate conflicting ops
- preserve history
- remain local-first

## 4. Cross-command conflict prevention

Single published conflict matrix + exact environment/resource locks.

Requirements:

- exact environment locks; exact resource locks
- no host-wide lock unless justified and documented
- deadlock prevention; stale lock detection; lock recovery; ownership audit

## 5. Unified CLI

```bash
sudo soviez.sh --operations
sudo soviez.sh --operation-status <operation-id>
sudo soviez.sh --operation-reattach <operation-id>
sudo soviez.sh --operation-cancel <operation-id>
sudo soviez.sh --operation-retry <operation-id>
sudo soviez.sh --operation-recover <operation-id>
sudo soviez.sh --operation-logs <operation-id>
```

Command-specific reattach/status CLIs remain as **backward-compatible aliases**.

## 6. Unified cancellation and rollback

Scope cancel before protected work; during safe waiting; after irreversible boundary → cancel-to-recovery; rollback eligibility/ownership; explicit confirmation; no silent destructive cancel; no cross-operation cleanup.

## 7. Orphan and reboot reconciliation

Unify: orphan workers, stale heartbeats, PID mismatch, missing systemd unit, state↔worker asymmetry, host reboot, interrupted promotion/deletion/restore, lock recovery, resume vs `recovery_required`.

## 8. Unified logs and redaction

One log location convention; per-op logs; structured events; bounded retention/rotation; redaction; no secrets/business data; operator summaries; optional support-bundle export only with explicit consent + redaction. **No external log shipping.**

## 9. Operation history and tombstones

Completed/failed/recovered history; deletion/cert/Stage/future migration tombstones; immutable audit fields; local retention; corruption detection.

## 10. Versioning and migration

Canonical `schema_version`; backward-compatible readers for Phase 8/11/12/13 records; non-destructive migration with backup; versioned transitions; upgrade tests; corruption handling.

## 11. Scheduler coordination

Coordinate SSL renewal, Stage retention, and future backup/update/migration workers:

- no duplicate scans / overlapping destructive actions
- bounded host load; priority + fairness
- manual op priority where appropriate
- no continuous SaaS dependency

## 12. Future-phase readiness (interfaces only)

Prepare shared plugs for Phase 15 Safe Update, 16 Backup/Restore, 17–22 Migration, 23 Offline Bundles. **Do not implement those phases in Phase 14.**

## Explicit non-goals

See `docs/ai/PHASE_14_SCOPE_CORRECTION.md` — no rebuild of 8/11/12/13 engines; no entitlement/retention/SSL policy changes; no update/backup/migration/offline implementation; no SaaS UI; no live deploy; no commit.
