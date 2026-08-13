# Performance and impact
Full backups are I/O heavy; default schedule 02:00 local; resource profile `balanced`.
Capacity preflight reduces disk-full mid-op risk.
Concurrency conflict-locked per Production backup/restore ops.
