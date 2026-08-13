# Source Runtime Suspension Options

| Option | Description | Phase 22 |
|--------|-------------|----------|
| A | Keep full runtime in maintenance | Allowed but not default (cost / attack surface) |
| **B** | **Stop ERP runtime; preserve host/data** | **Recommended default** |
| C | Stop host; preserve disks/snapshots | Allowed after verified archive; provider-specific |
| D | Delete host after archive | **Excluded** (destructive) |

## Recommended posture

- Stop public ERP runtime + business integrations
- Keep host intact
- PostgreSQL may stop only after archive verification
- No volume deletion / no host deletion
- No provider API required for PASS (manual path first-class)
