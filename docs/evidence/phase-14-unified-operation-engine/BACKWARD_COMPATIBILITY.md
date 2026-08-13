# Backward Compatibility

**Phase:** 14  
**Verdict:** PASS  

## 1. Zero-Disruption Strategy

To maintain seamless backward compatibility with existing admin automations, cron-jobs, and production environments:

- **No Breaking Aliases:** All preexisting reattach flags (`--reattach`, `--stage-reattach`, `--ssl-reattach`, `--stage-retention-reattach`) map directly to the unified `soviez_ops_adapter_reattach` command helper.
- **Sidecar JSON Writes:** For operations located in Stage, SSL, and retention workspaces, the migration engine writes a `canonical.json` next to the old `state.json` file. This lets existing legacy state readers parse operational statuses without throwing parsing faults.
- **No Schema Collisions:** The canonical schema embeds old step strings directly inside `current_checkpoint`, preserving step-level states perfectly for backward-compatible state engines.
