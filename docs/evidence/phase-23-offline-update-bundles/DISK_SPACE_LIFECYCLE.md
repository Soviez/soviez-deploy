# DISK_SPACE_LIFECYCLE — Phase 23 disposable certification

Generated: 2026-08-09T19:38:00Z (approx local 22:38 +03)

## Host disk baseline (BEFORE)

| Volume | Size | Used | Avail | Capacity |
|--------|------|------|-------|----------|
| `/` (system APFS) | 228Gi | 12Gi (system) / Data 119Gi | **85Gi** | 13% / Data 59% |
| `/Volumes/PortableSSD` | 932Gi | 417Gi | **515Gi** | 45% |

Reserve policy: keep ≥15–20 Gi free on system volume at all times. Baseline meets reserve (**85 Gi** free).

## Colima / Lima locations

| Path | Size | Notes |
|------|------|-------|
| `~/.colima` | symlink → PortableSSD Colima Home | |
| `/Volumes/PortableSSD/Apps/Colima/Home/.colima` | **23G** | actual data |
| `~/.lima` | absent | |
| `/Volumes/PortableSSD/Apps/Colima/Home/.lima` | 0B | unused; Colima embeds Lima under `.colima/_lima` |

## Profile inventory (`colima list`)

```text
PROFILE    STATUS     ARCH       CPUS    MEMORY    DISK     RUNTIME
default    Running    aarch64    4       6GiB      40GiB    docker
```

- Profile name: **`default`** (pre-existing)
- Allocated VM disk: **40 GiB**
- Host-side Colima home usage: **~23 G**
- VM `/var/lib/docker` after recovery start: **26 GiB free / 40 GiB** (32% used)
- Docker images ≈ **12.29 GB**; volumes ≈ **300 MB**

## Disposability verdict — DO NOT DELETE

Positive proof that profile `default` is **not** a disposable certification-only VM:

| Resource | Why retained |
|----------|----------------|
| `wab-poc-postgres-1` + volume `wab-poc_poc_postgres_data` | Unrelated Chatwoot/WhatsApp POC database |
| `wab-poc-redis-1`, `wab-poc-rails-1`, … | Unrelated POC stack |
| `soviez-rc-db-pass5-*`, `soviez-rc-db-pass4-*`, `soviez-rc-db-20260805*` | Persistent RC/dev Postgres fixtures |
| `soviez-rc-web-pass5-*` | Local ERP RC container |
| Volumes `soviez-p17-persist`, `soviez-p17-sh` | Prior-phase persistent fixtures |
| ERP images `soviez/erp:p15-v*-labeled`, `soviez-erp:…-pass5` | Multi‑GB reusable certification images |

Lifecycle policy for this run: **exact Phase‑23 labeled cleanup + `colima stop` only. No `colima delete`.**

## Repository / test assumption

Phase 23 helpers and suites hard-code / default to:

```text
DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
```

Therefore this lifecycle uses the **`default`** profile (not a new `soviez-cert` profile).

## Recovery start (one attempt)

VM was in invalid VZ state (`The virtual machine is no longer live` / empty runtime). Exactly one `colima stop` then one `colima start` restored Docker. No retry storm.

## Docker reclaimable (BEFORE cert)

```text
Images 12.29GB (788.7MB reclaimable)
Containers 430.1MB
Local Volumes 300.5MB (0B reclaimable — all in use by non-cert workloads)
```

## Peak-low / AFTER (PASS run)

| Metric | Value |
|--------|-------|
| System free BEFORE | 85 Gi |
| System free PEAK LOW | ~83.2 Gi |
| System free AFTER | 83 Gi |
| PortableSSD BEFORE/AFTER | 515 Gi / 515 Gi |
| Colima home BEFORE/AFTER | 23 G / 23 G (stopped, not deleted) |
| Temp workspace AFTER | 0 B |

Reusable lifecycle: `tests/phase23_ephemeral_certification_lifecycle.sh --ephemeral`

Details: `DISK_CLEANUP_REPORT.md`.