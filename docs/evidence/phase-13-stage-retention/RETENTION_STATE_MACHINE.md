# Retention State Machine
`active` derives to `extension_available`, `extension_limit_reached`, or `deletion_due`.

Due execution: `final_backup_running` → `safe_shield_validating` → `deletion_running` → deleted/tombstoned. Failure becomes `needs_action` (backup/validation/ambiguity) or `recovery_required` (partial deletion). Durable completed-step records make retry and reattach idempotent.
