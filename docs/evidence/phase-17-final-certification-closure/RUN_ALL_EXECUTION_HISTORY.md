# RUN_ALL Execution History — Phase 17 Final Certification Closure

## Required wording

```text
The earlier sandbox-constrained tests/run_all.sh execution failed because
Docker-dependent suites could not access the Colima socket.
A later full-permission execution successfully accessed the required Docker
runtime and completed with:
run_all: PASS
The later execution supersedes the sandbox-constrained run for regression
certification purposes. The earlier result remains documented as an
environment-access limitation.
Phase 17 remained PARTIAL due to separately documented acceptance gaps.
```

## Run A — sandbox-constrained (FAILED — environment-access limitation)

| Field | Value |
|-------|-------|
| Classification | `sandbox-constrained result` |
| Command | `tests/run_all.sh` (and Docker probe) |
| Working directory | `/Volumes/PortableSSD/soviez-project/soviez-sh` |
| Result | **FAILED** |
| Root cause | Colima Docker socket unreachable from sandbox (`permission denied` on `unix:///Users/raafatagha/.colima/default/docker.sock`) |
| Product defect? | **No** — environment-access limitation |
| Evidence | `SANDBOX_FAILURE_ANALYSIS.md`, `sandbox_docker_probe_*.log` |
| Must not claim | Must **not** be rewritten as PASS |

## Run B — full-permission intermediate (FAILED — fixture orphan after reboot)

| Field | Value |
|-------|-------|
| Classification | full-permission (non-authoritative intermediate) |
| Timestamp (UTC) | `20260801T181646Z` |
| Result | **FAILED** |
| Failures | `test_backup_s3_real.sh` (MinIO bucket), later `test_update_final_certification.sh` on an earlier attempt when reboot ran mid-suite |
| Root cause | Colima reboot deleted docker network; MinIO/SFTP containers orphaned; reboot matrices mid-alphabet disrupted later Docker suites |
| Fix | Recreate fixtures on start failure; defer reboot matrices to end of `run_all` |
| Evidence | `FULL_PERMISSION_RUN_ALL_PRIOR_FAILED_S3_SFTP.log` (if present) |

## Run C — full-permission authoritative (PASS)

| Field | Value |
|-------|-------|
| Classification | `full-permission authoritative result` |
| Command | `tests/run_all.sh` |
| Working directory | `/Volumes/PortableSSD/soviez-project/soviez-sh` |
| Timestamp (UTC) | `20260801T190334Z` |
| `DOCKER_HOST` | `unix:///Users/raafatagha/.colima/default/docker.sock` |
| Docker/Colima | `docker info=OK`, Colima socket reachable |
| Exit code | `0` |
| Summary | `run_all: PASS` |
| Log | `FULL_PERMISSION_RUN_ALL.log` |
| Checksum | see `FULL_PERMISSION_RUN_ALL.log.sha256` |

## Why Run C supersedes Run A

Run A could not exercise Docker-dependent suites. Run C accessed the required Docker runtime and completed every suite including Phase 16 S3/SFTP, Phase 17 destination host, and host-level reboot matrices (last). Run A remains documented honestly as an environment-access limitation. Phase 17 PARTIAL was due to **acceptance gaps**, not solely the sandbox failure; those gaps are closed separately (see `PARTIAL_GAP_LEDGER.md`).
