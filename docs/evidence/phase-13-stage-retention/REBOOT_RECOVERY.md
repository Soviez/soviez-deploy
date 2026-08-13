# Reboot Recovery
Retention state is stored locally, not in process memory. Scheduler scan recalculates due state, re-renders warnings/banner, and resumes due deletion from persisted metadata.

Integration simulates reboot conditions by clearing a stale test lock, advancing the clock beyond deadline, invoking scheduler scan, and verifying the Stage tombstone.
