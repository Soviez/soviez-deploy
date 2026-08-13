# Existing Engine Inventory

**Phase:** 14  
**Verdict:** PASS  

## 1. Legacy Engine Assessment

Prior to Phase 14, operations were managed via separate, disjoint logic branches. The following list identifies these legacy structures, all of which are preserved and reused via Phase 14 command adapters:

### 1. Phase 8 (License Activation)
- **Source:** `src/operations/engine.sh`, `src/operations/state_machine.sh`
- **Output:** `$SOVIEZ_OPS_ROOT/operations/<id>/state.json`
- **Capabilities:** License credentials, device activation binds, and local checks.

### 2. Phase 11 (Stage Creation)
- **Source:** `src/stage/engine.sh`, `src/stage/admission.sh`
- **Output:** `$SOVIEZ_STAGE_OPS_DIR/<id>/state.json`
- **Capabilities:** DB dump, Stage cluster networks setup, filestore rsync.

### 3. Phase 12 (Domain/SSL Lifecycle)
- **Source:** `src/ssl/engine.sh`, `src/ssl/validate.sh`
- **Output:** `$SOVIEZ_SSL_OPS_DIR/<id>/state.json`
- **Capabilities:** ACME challenge hooks, Let's Encrypt DNS verification.

### 4. Phase 13 (Stage Retention)
- **Source:** `src/stage/retention_engine.sh`
- **Output:** `$SOVIEZ_OPS_ROOT/retention/inventory.json`
- **Capabilities:** Tombstones, final backups, Safe Shield validation.
