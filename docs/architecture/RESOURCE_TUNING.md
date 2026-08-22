# Resource tuning architecture

See [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md) §9 and [user/TUNING.md](../user/TUNING.md).

## Commands

```bash
soviez.sh --tune
soviez.sh --tune --dry-run
soviez.sh --tune --explain    # APPROVED; not yet implemented
```

## Sizing inputs

CPU, RAM, swap, storage I/O, DB size, filestore size, Production count, Stage count (active), security-service overhead, host reserve.

## Outputs

**Odoo:** workers, cron threads, memory/time limits, proxy_mode, gevent_port when applicable.

**PostgreSQL:** shared_buffers, work_mem, connections, WAL, parallel workers, logging thresholds.

**Docker:** shm_size, resource limits/reservations, Stage caps.

## Resize

After VPS resize, re-run `--tune`. Supports resize-up/down with checkpoint and rollback.

## Idempotency

No effective change → no unnecessary restart.
