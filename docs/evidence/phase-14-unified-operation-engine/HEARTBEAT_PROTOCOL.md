# Heartbeat Protocol

**Phase:** 14  
**Verdict:** PASS  

## 1. Heartbeat Specifications

Workers log progress by continuously updating their heartbeat to prevent stale timeouts.

- **Heartbeat File:** Located at `$SOVIEZ_OPS_ROOT/operations/<operation_id>/heartbeat`.
- **Update Frequency:** Recommended update is every 30 seconds during active transitions.
- **Timeout Window:** Evaluators use a 300-second window. An operation is marked `OPERATION_HEARTBEAT_STALE` only if the timestamp is older than 300 seconds **and** the worker process PID is dead.
- **Heartbeat Checks:** `soviez_ops_heartbeat_stale` reads and parses the timestamp relative to host-timezone system clocks.
