# DOCKER_COLIMA_DIAGNOSTICS

## Prior failure (run-B)
Positive evidence of Colima VM disk exhaustion during disposable Postgres initdb:

```text
FATAL: could not write to file "pg_wal/xlogtemp.44": No space left on device
```

Cascade: containers not running / No such container / candidate PG not ready across migration, stage, restore, update, SaaS disposable proofs.

## Containment (does not weaken tests)
- `soviez_phase23_docker_disk_ok` fails closed below 1.5GiB free
- `soviez_phase23_docker_preflight` requires reachable daemon
- Exact disposable cleanup by label `soviez.phase23.disposable=1` / name `soviez-p23-*` only
- No global prune; no broad volume deletion in cert path
- `--rm` removed from disposable PG scripts until readiness proven

## Resume check (2026-08-09 morning)
Colima running (vz/aarch64); Docker server reachable; `/var/lib/docker` free space reported in ENVIRONMENT_PREFLIGHT.md after authoritative preflight.

## Resume check (2026-08-09 evening) — BLOCKER
Exact observed errors (no Colima start loop):

```text
$ colima status
time="2026-08-09T20:50:45+03:00" level=fatal msg="colima is not running"

$ docker info
permission denied while trying to connect to the docker API at unix:///Users/raafatagha/.colima/default/docker.sock

$ # bounded re-check (later hung >30s with no further output)
```

### Bounded diagnostic result (2026-08-09T21:04:03+03:00)
```text
$ colima status
fatal msg="error retrieving current runtime: empty value"  (exit 1)

$ limactl list
warning: No instance found. Run `limactl create` to create an instance.

$ ls ~/.colima/default/docker.sock
# socket file still present (stale)

$ docker info
Cannot connect to the Docker daemon at unix:///Users/raafatagha/.colima/default/docker.sock.
Is the docker daemon running?
```

**Action required outside agent:** restore a healthy Colima/Lima instance (not agent `colima start` loops), verify `colima status` + `docker info` + `docker ps`, then one clean `tests/phase23_authoritative_certification.sh`.

