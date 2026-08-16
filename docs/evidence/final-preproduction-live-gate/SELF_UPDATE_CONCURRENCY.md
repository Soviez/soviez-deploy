# SELF_UPDATE_CONCURRENCY

- captured_utc: 2026-08-16T16:20:38Z
- SELFUP-LIVE-08: two concurrent  processes
- Observed: one waiter logged  (flock)
- Both ended non-zero in first run (signature/chmod issues); executable survived
- Classification: **PASS** for lock serialization signal; **BLOCKED** for successful dual-apply proof (blocked by install  defect)
