# Configuration Reference

## Classes

| Class | Meaning |
|-------|---------|
| operator-editable | Intentional operator settings |
| generated | Written by Soviez — edit with care |
| internal | Operation state machines |
| do-not-edit | Integrity-sensitive |

## Common locations

| Path | Class | Content |
|------|-------|---------|
| `/etc/soviez/device` | internal | Device binding |
| `/etc/soviez/secrets` | do-not-edit | Secrets |
| `/var/soviez/tenant/*/tenant.soviez.conf` | generated | Odoo conf (`proxy_mode`, workers, DB) |
| `/etc/nginx/sites-* /soviez-*.conf` | generated | Nginx vhosts |
| `/etc/nginx/conf.d/soviez_limits.conf` | generated | Upgrade map / limits |
| `/var/soviez/ops` | internal | Operation registry |
| `/var/soviez/stages` | internal | Stage inventory + retention |
| SSL inventory under Soviez SSL root | generated | Certificates |

## Odoo generated highlights

- `proxy_mode = True`
- `list_db = False`
- Workers calculated by `soviez.sh --tune` (automatic sizing; may be 0 on small hosts)
- When multi-worker: `gevent_port = 8072`

## Nginx generated highlights

- Public `:80`/`:443`
- Upstream HTTP to `127.0.0.1:HOST_PORT` → container 8069
- `/websocket` and `/longpolling` → evented backend `127.0.0.1:8072` when multi-worker topology is active
