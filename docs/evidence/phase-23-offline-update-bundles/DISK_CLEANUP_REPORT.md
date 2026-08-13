# DISK_CLEANUP_REPORT — Phase 23 ephemeral certification lifecycle

Generated: 2026-08-09T21:03:00Z

## Verdict linkage
- Certification: **PASS** (`aggregate_exit_code=0`)
- Cleanup success does not redefine PASS (cert already PASS before cleanup)

## Disk free

| Metric | Value |
|--------|-------|
| System free BEFORE | **85 Gi** |
| System free PEAK LOW (sampler) | **~83.2 Gi** (min 1K-blocks 87225104 on PASS run) |
| System free AFTER | **83 Gi** |
| PortableSSD free BEFORE | **515 Gi** |
| PortableSSD free AFTER | **515 Gi** |
| Colima home BEFORE | **23 G** |
| Colima home AFTER | **23 G** (VM stopped, not deleted) |

Approximate host reclaim from this lifecycle: **temp workspace → 0B** (deleted). VM disk image retained (~20 Gi raw + datadisk) because profile is **not disposable**.

## Docker resources

### Before cert (inventory)
- Unrelated: `wab-poc-*` containers + volumes (`wab-poc_poc_postgres_data`, redis, chatwoot, gowa)
- Persistent RC: `soviez-rc-db-*`, `soviez-rc-web-pass5-*`
- Prior-phase: `soviez-p17-persist`, `soviez-p17-sh`
- Images ≈ 12.29 GB / 19 images

### Removed by exact cleanup (this run)
- Containers with `label=soviez.phase23.disposable=1`
- Containers/networks/volumes with `label=com.soviez.owner=phase23-cert` (none newly labeled beyond helper convention)
- Names matching `soviez-p23-*`
- Exact fixture reset via `soviez_phase23_exact_fixture_reset`
- Dangling (unreferenced) volumes only
- Exact temp dir: `/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T201641Z-78190`

### Intentionally NOT removed
- All `wab-poc_*` containers/volumes
- All `soviez-rc-*` RC DB/web containers
- Volumes `soviez-p17-*`
- ERP/RC images (`soviez/erp:p15-v*-labeled`, `soviez-erp:…-pass5`)
- Colima VM / profile `default`

## Temporary sizes (run-owned)
- Temp workspace root: `.phase23-cert-tmp/<run-id>/` on PortableSSD (included OCI/bundle/reboot fixtures under TMPDIR)
- After cleanup: **0B** (directory empty/removed)

## Colima lifecycle
| Step | Result |
|------|--------|
| Start | One recovery start (invalid VZ → stop+start) then PASS-run start |
| Stop | Lifecycle trap stopped Colima; re-verified Stopped after a post-run restart race |
| Delete | **NOT performed** — disposability UNSAFE (see manifest) |

## Final state
```text
Phase23 temporary workspaces = 0
Colima profile default = Stopped (retained)
colima delete = skipped (unrelated POC DBs + RC ERP + reusable images)
```

## Safety
- No `docker system prune`, no `volume prune -a`, no `rm -rf ~/.colima|~/.lima`
- No source/`.git`/evidence/artifact deletion
- Failed-run history retained (`_EPHEMERAL_CONSOLE.fail-finalizer-F31-*.log`, prior `_AUTH_CONSOLE.*`)
