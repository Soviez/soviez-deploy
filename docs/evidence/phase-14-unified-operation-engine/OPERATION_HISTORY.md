# Operation History Specifications

**Phase:** 14  
**Verdict:** PASS  

## 1. Audit Trail

When an operation transitions to a terminal state (`completed`, `canceled`, `failed_terminal`), the unified state engine triggers an automatic log append:

- **History File:** `$SOVIEZ_OPS_ROOT/registry/history/<operation_id>.jsonl`
- **Permissions:** Strict `0600` permissions.
- **Append Behavior:** Appends the full canonical JSON record representing the terminal state to the log file.
- **History Retrieval:** Run `soviez_ops_history_list` or `soviez --operations --failed` to fetch and format historical audit reports locally.
