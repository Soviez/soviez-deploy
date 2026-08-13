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
- Default `workers = 0` on first provision

## Nginx generated highlights

- Public `:80`/`:443`
- Upstream to `127.0.0.1:HOST_PORT` → container 8069
- `/websocket` on ERP template; S2 also adds `/longpolling` to same upstream
