# Failure Injection

**Phase:** 14  
**Verdict:** PASS  

## 1. Safety Hardening Verification

To verify that the engine handles runtime failures gracefully, multiple failure modes were simulated:

- **Corrupt JSON State:** Injecting invalid syntax into `canonical.json` throws `OPERATION_STATE_CORRUPT` and aborts safely instead of trying to process bad structures.
- **PID Collisions:** Simulating PID reuse by creating an active process with the target PID but a non-Soviez commandline string (e.g. running `sleep`) is detected by the FQDN check and process-command filters. The engine transitions the operation to `recovery_required` and aborts.
- **Mismatched FQDN:** Forcing a mismatch between `host_identity` and the current system hostname immediately flags `recovery_required` and denies lock acquisitions to prevent multi-host split-brain scenarios.
