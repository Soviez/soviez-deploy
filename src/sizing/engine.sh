# shellcheck shell=bash
# Deterministic resource sizing engine (Odoo + PostgreSQL + Docker/SHM).

soviez_sizing_detect_cpu() {
  if [[ -n "${SOVIEZ_SIZING_FORCE_CPU:-}" ]]; then
    printf '%s\n' "$SOVIEZ_SIZING_FORCE_CPU"
    return 0
  fi
  if command -v nproc >/dev/null 2>&1; then
    nproc
    return 0
  fi
  sysctl -n hw.ncpu 2>/dev/null || printf '1\n'
}

soviez_sizing_detect_ram_mb() {
  if [[ -n "${SOVIEZ_SIZING_FORCE_RAM_MB:-}" ]]; then
    printf '%s\n' "$SOVIEZ_SIZING_FORCE_RAM_MB"
    return 0
  fi
  if [[ -r /proc/meminfo ]]; then
    awk '/MemTotal:/ {printf "%d\n", $2/1024; exit}' /proc/meminfo
    return 0
  fi
  local bytes
  bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
  printf '%d\n' "$((bytes / 1024 / 1024))"
}

# Emit JSON sizing profile to stdout.
soviez_sizing_calculate() {
  local cpu ram_mb prod_n stage_n db_mb fs_mb
  cpu="$(soviez_sizing_detect_cpu)"
  ram_mb="$(soviez_sizing_detect_ram_mb)"
  prod_n="${1:-1}"
  stage_n="${2:-0}"
  db_mb="${3:-0}"
  fs_mb="${4:-0}"

  python3 - "$cpu" "$ram_mb" "$prod_n" "$stage_n" "$db_mb" "$fs_mb" <<'PY'
import json, sys, math
cpu=max(1,int(float(sys.argv[1])))
ram=max(512,int(float(sys.argv[2])))
prod=max(0,int(float(sys.argv[3])))
stage=max(0,int(float(sys.argv[4])))
db_mb=max(0,int(float(sys.argv[5])))
fs_mb=max(0,int(float(sys.argv[6])))

# Host reserves: OS + nginx + docker + clamav/yara + fs cache headroom
reserve = max(768, int(ram * 0.22))
security_headroom = 256 if ram >= 4096 else 128
stage_reserve = min(int(ram * 0.08) * max(stage, 0), int(ram * 0.20))
usable = max(512, ram - reserve - security_headroom - stage_reserve)

# Odoo workers: leave room for PG + cron + gevent + scanners
# Conservative cap: at most 1 worker per CPU (not classic 2*cpu+1)
per_worker_mb = 220
max_by_cpu = max(0, cpu)
max_by_mem = max(0, int((usable * 0.35) / per_worker_mb))
workers = min(max_by_cpu, max_by_mem)
# Conservative: sub-6GiB or single CPU cannot safely host multiprocessing + PG + scanners
if ram < 6144 or cpu < 2:
    workers = 0  # explicit minimal fallback
elif ram < 8192:
    workers = min(workers, max(1, cpu // 2 or 1))
workers = int(workers)

max_cron = 1 if workers == 0 else max(1, min(2, cpu // 2))
limit_soft = per_worker_mb * 1024 * 1024
limit_hard = int(limit_soft * 1.5)
limit_time_cpu = 60
limit_time_real = 120
limit_request = 8192

# PostgreSQL share of usable RAM
pg_budget = int(usable * 0.40)
shared_buffers = max(128, min(int(pg_budget * 0.35), 8192))
effective_cache = max(shared_buffers * 2, min(int(usable * 0.50), ram - reserve))
work_mem = max(4, min(64, int((pg_budget * 0.10) / max(1, workers + 4))))
maint_work = max(64, min(1024, int(pg_budget * 0.10)))
max_conn = max(40, min(200, 40 + workers * 4 + stage * 8))
effective_io = 200  # SSD default; HDD override via env later
random_page = 1.1
checkpoint = 0.9
min_wal = 1024
max_wal = max(2048, min(8192, shared_buffers))
max_worker_processes = max(2, min(cpu, 8))
max_parallel = max(1, min(cpu // 2, 4))
max_parallel_gather = max(1, min(2, max_parallel))

# Docker SHM for PG (bytes-like MB)
shm_mb = max(64, min(shared_buffers, int(ram * 0.15)))

profile = {
  "cpu": cpu,
  "ram_mb": ram,
  "usable_mb": usable,
  "host_reserve_mb": reserve,
  "security_headroom_mb": security_headroom,
  "stage_reserve_mb": stage_reserve,
  "productions": prod,
  "stages": stage,
  "odoo": {
    "workers": workers,
    "max_cron_threads": max_cron,
    "limit_memory_soft": limit_soft,
    "limit_memory_hard": limit_hard,
    "limit_time_cpu": limit_time_cpu,
    "limit_time_real": limit_time_real,
    "limit_request": limit_request,
    "proxy_mode": True,
    "list_db": False,
    "gevent_port": 8072 if workers > 0 else None,
    "http_port": 8069,
  },
  "postgres": {
    "shared_buffers_mb": shared_buffers,
    "effective_cache_size_mb": effective_cache,
    "work_mem_mb": work_mem,
    "maintenance_work_mem_mb": maint_work,
    "max_connections": max_conn,
    "effective_io_concurrency": effective_io,
    "random_page_cost": random_page,
    "checkpoint_completion_target": checkpoint,
    "min_wal_size_mb": min_wal,
    "max_wal_size_mb": max_wal,
    "max_worker_processes": max_worker_processes,
    "max_parallel_workers": max_parallel,
    "max_parallel_workers_per_gather": max_parallel_gather,
    "log_min_duration_statement_ms": 1000,
    "log_lock_waits": True,
  },
  "docker": {
    "postgres_shm_mb": shm_mb,
  },
  "topology": {
    "http_backend": "127.0.0.1:8069",
    "websocket_backend": "127.0.0.1:8072" if workers > 0 else "127.0.0.1:8069",
    "mode": "multi_worker_gevent" if workers > 0 else "single_worker_compat",
  },
}
print(json.dumps(profile, indent=2, sort_keys=True))
PY
}
