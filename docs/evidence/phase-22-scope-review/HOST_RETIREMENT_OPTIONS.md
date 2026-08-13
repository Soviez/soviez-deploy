# Host Retirement Options

| Path | Description | Phase 22 |
|------|-------------|----------|
| Manual retirement | Stop services; preserve host; owner verifies archive; later terminate | **First-class**, provider-neutral |
| Provider-adapter suspension | Stop instance; preserve disks/snapshots; exact resource | Allowed after archive verify; not required for PASS |
| Provider-adapter termination | Destroy host | **Excluded** unless separately authorized later |

No provider API required for Phase 22 PASS.
