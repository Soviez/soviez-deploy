# Disk-space certification lifecycle

Reuse Phase 23/24 ephemeral principles:
- Exact disposable labels; run-owned temp workspaces
- No global prune; preserve evidence
- Clean after run; stop Colima if started by run
- Delete only dedicated disposable VM proven safe
- Preserve `wab-poc_*`, RC, unrelated resources

## Budget (planning)
- Reserve ≥20% free on cert volume before matrix
- Peak headroom for dual ERP images + PG + offline OCI
- Exact reclaim dangling volumes between suites (as run_all does)
