# Partial Deletion Recovery
The deletion engine records each completed named step. An injected database failure after container stop creates `RETENTION_PARTIAL_DELETION`, `recovery_required`, and preserves remaining Stage evidence.

After the fault clears, retry resumes from the first incomplete step and writes a tombstone. Partial deletion is never silently treated as success.
