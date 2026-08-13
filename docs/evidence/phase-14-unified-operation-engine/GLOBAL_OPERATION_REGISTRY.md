# Global Operation Registry

**Phase:** 14  
**Verdict:** PASS  

## 1. Registry Architecture

The local index folder is located at `$SOVIEZ_OPS_ROOT/registry/index/`. It contains shallow JSON summaries of active and historical operations to support sub-millisecond querying without directory crawling.

Summary fields include:
- `operation_id`
- `operation_type`
- `environment_id`
- `current_state`
- `current_checkpoint`
- `updated_at`
- `heartbeat_at`
- `canonical_path`

## 2. Re-indexing & Reconciliation

If the index folder is lost or deleted, running `soviez --operation-reconcile` (which runs `soviez_ops_registry_reconcile_index`) crawls `$SOVIEZ_OPS_ROOT/operations/`, `$SOVIEZ_STAGE_OPS_DIR/`, and `$SOVIEZ_SSL_OPS_DIR/` directories, triggers auto-migration on raw state files, and regenerates index files completely. No state loss occurs.
