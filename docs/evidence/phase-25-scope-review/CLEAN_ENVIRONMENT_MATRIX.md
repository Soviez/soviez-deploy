# Clean-environment matrix

Mandatory environments (risk-based, not full Cartesian):
1. Ubuntu 22.04 amd64 clean connected
2. Ubuntu 24.04 amd64 clean connected
3. One clean air-gapped environment (either OS)
4. Shared disposable Docker/Colima cert lifecycle for Stage/update/migration suites

Redundant avoided: every E2E × both OS × all remotes.
