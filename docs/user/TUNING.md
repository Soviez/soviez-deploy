# Automatic resource tuning

**Command:**

```bash
soviez.sh --tune
soviez.sh --tune --dry-run
```

## Purpose

Re-detect current server resources and recalculate safe Odoo / PostgreSQL / Docker runtime configuration. Supports VPS resize:

```text
detect → calculate → compare → present plan → checkpoint → apply → validate → restart only if required → verify
```

On failure, previous known-good configuration is restored.

## What is sized

- Odoo: `workers`, `max_cron_threads`, memory/time/request limits, `proxy_mode`, `list_db`, `gevent_port` when multi-worker
- PostgreSQL: buffers, work_mem, connections, WAL/checkpoint, parallel workers (recommended profile)
- Docker: PostgreSQL `/dev/shm` recommendation integrated with total memory budget

Soviez automatically sizes runtime configuration from available server resources. Formulas are internal and may change; they are not public SLAs.

## Headroom

Sizing leaves headroom for PostgreSQL, OS, filesystem cache, Nginx, Docker, ClamAV, YARA, backups, Stage workloads, and scheduled tasks.

## Idempotency

Running `--tune` twice without resource change produces no effective changes and avoids unnecessary restart.
