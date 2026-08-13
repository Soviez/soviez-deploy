# Security Adversary Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Threat Mitigation Analysis

The threat landscape for host-bound operation execution was verified against multiple adversarial vectors:

- **Threat: Malicious State Mutation**
  - *Vector:* Injecting database credentials or private keys into `canonical.json` or state directories.
  - *Mitigation:* The JSON validator recursive scanner checks for keys matching `password`, `token`, `secret`, `private_key` etc. Saves are blocked instantly on failure.
- **Threat: Hijacking Background Workers**
  - *Vector:* Overwriting or injecting environment variables into background units.
  - *Mitigation:* Systemd units read variables exclusively from a dedicated, secure environment file at `$SOVIEZ_OPS_ROOT/operations/<id>/worker.env` configured with strict `0600` permissions and owned by root.
- **Threat: Multi-Host Split-Brain**
  - *Vector:* Reattaching or retrying operations on a different machine in high-availability environments.
  - *Mitigation:* The identity check verifies `host_identity` matches the local FQDN. Mismatches block lock acquire and transition the operation to `recovery_required`.
- **Threat: Secret Leakage in Logs**
  - *Vector:* Commands emitting connection URLs or secrets in stderr.
  - *Mitigation:* `soviez_ops_log_append` routes all stdout and stderr streams through the central regex-based scrubber `soviez_redact_text` before committing to files.
