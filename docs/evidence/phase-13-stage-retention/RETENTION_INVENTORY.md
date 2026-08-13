# Retention Inventory
Per-Stage `retention.json` records `stage_id`, immutable `created_at`, immutable `maximum_retention_deadline`, requested total days, current deadline, status/countdown, warning/deletion state, operation ID, backup evidence, Safe Shield result, and completed deletion steps.

Writes are atomic. Existing records reject changes to immutable creation/max fields. Warning ledger, banner files, deletion lock, and tombstones are also local per-Stage artifacts.
