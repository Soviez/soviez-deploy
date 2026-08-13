# Performance sanity (not SLAs)

Record only operational observations:
- installer duration
- backup/restore duration
- update duration
- migration throughput
- offline bundle apply duration
- startup time / health-check time
- disk peak / temp cleanup

No SLA promises. Fail only on pathological hangs/timeouts defined by existing harness bounds.
