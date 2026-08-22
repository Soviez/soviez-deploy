# Runtime topology

See [SOVIEZ_SH_PRODUCT_CONTRACT.md](../SOVIEZ_SH_PRODUCT_CONTRACT.md) §9.

## Adaptive workers

Soviez sizes `workers` from host resources. **Not** workers=0-only.

| Profile | Odoo | Nginx |
|---------|------|-------|
| Small host | `workers=0`, single process on `:8069` | `/`, `/websocket`, `/longpolling` → `:8069` |
| Multi-worker | HTTP `:8069`, gevent `:8072` | `/` → `:8069`; `/websocket` → `:8072` |

## Network layout

```text
Internet → :443 Nginx (TLS)
         → 127.0.0.1:8069 Odoo HTTP
         → 127.0.0.1:8072 Odoo evented (when workers > 0)

PostgreSQL: Docker backend network only (no public :5432)
```

## Platform CLI

```text
/usr/local/bin/soviez.sh → /opt/soviez/platform/current/soviez.sh
```

Not a daemon. Long operations use persistent jobs / systemd workers.
