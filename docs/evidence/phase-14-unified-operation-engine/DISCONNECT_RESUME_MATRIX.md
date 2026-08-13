# Disconnect/Resume Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Resiliency Verification

The disconnect/resume matrix tests system resilience against network/session termination:

- **Kill SSH Mid-Op:** A worker launched in background (systemd service or test nohup) continues running independently when SSH terminates.
- **Auto-Liveness Recovery:** Re-establishing the SSH connection and calling `soviez --operation-status <id>` automatically queries the global index and confirms worker process liveness.
- **Reattach Re-entry:** Running `soviez --operation-reattach <id>` delegates execution to the command-specific engine, skipping already completed checkpoints and re-joining stdout streams.
