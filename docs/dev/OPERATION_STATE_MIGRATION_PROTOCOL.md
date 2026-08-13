# Operation State Migration Protocol

**Phase:** 14  
**Version:** `0.14.0-phase14`  
**Schema Version:** `1`  

## 1. Objective

To support seamless backward compatibility, the Unified Operation Engine provides an automatic, idempotent migration mechanism to upgrade legacy operation states (`state.json` files or retention records from Phase 8, 11, 12, and 13) into the Phase 14 canonical JSON format (`canonical.json`).

## 2. Idempotency & Safety Protocol

1. **Destructive Protection:** Legacy files are never deleted or corrupted. Before any conversion occurs, the legacy source file is backed up to `<filename>.pre-phase14.bak`.
2. **Re-entry Safety:** If `canonical.json` already exists under the operation's workspace directory, the migration checks if the legacy state matches. If they match or if the legacy state has not progressed beyond the canonical checkpoint, the migration short-circuits gracefully with exit code `0`.
3. **Dual-write Sidecars:** For Phase 11/12/13 operations where workspaces differ from the default Phase 8 layout, a copy of the canonical file is written next to the legacy state file as a sidecar, ensuring both old command-specific readers and the new unified CLI can read the status.

## 3. Legacy State Mapping Rules

Since earlier phases used heterogeneous state strings, they are mapped to the top-level Phase 14 lifecycle states via the following conversion tree:

```text
Legacy State/Checkpoint              Phase 14 top-level state
─────────────────────────────────►  ────────────────────────
completed                           completed
canceled                            canceled
failed_terminal                     failed_terminal
failed_retryable                    failed_retryable
recovery_required                   recovery_required

waiting_for_dns
waiting_for_connection_consent
device_authorization_pending        waiting
manual_activation_pending
ssl.waiting_for_dns
retention.waiting

(All other states, e.g.             running
 database_restore, nginx_reload)
```

The fine-grained legacy step is preserved perfectly inside the `current_checkpoint` field of the canonical record.

## 4. Migration Execution

### Auto-migration Trigger
Implicit migration occurs during any unified CLI command (e.g. `soviez --operation-status <op_id>` or `soviez --operation-reattach <op_id>`). If the operation is not indexed in the global registry, the engine scans candidate directories, loads the legacy files, migrates them, writes the `canonical.json` and sidecar, and registers the operation.

### Bulk Migration & Dry Runs
The CLI provides bulk migration capabilities:
- `--operations --dry-run`: Scans all Phase 8/11/12/13 workspace directories and lists files scheduled for upgrade without modifying any records on disk.
- `--operations --migrate`: Commits the upgrades and indexes all discovered historical operations.

### Continuous Sync Migration Integration
For active operations running on legacy engines, the migration rules are continuously applied in real-time by the synchronization module (`src/ops/sync.sh`). Any legacy state transition or checkpoint update triggers an automatic, idempotent canonical upgrade transaction, ensuring that active operations remain fully aligned with the Phase 14 unified schema without executing bulk migration commands.
