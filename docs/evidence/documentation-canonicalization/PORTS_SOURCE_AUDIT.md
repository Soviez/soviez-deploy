# PORTS_SOURCE_AUDIT

| Port | Purpose | Binding | Exposure | Owner |
|------|---------|---------|----------|-------|
| 22 | SSH | host | PUBLIC | wizard UFW / S2 |
| 80 | HTTP/ACME | Nginx | PUBLIC | ERP/S2 |
| 443 | HTTPS | Nginx | PUBLIC | ERP/S2 |
| 8069 | Odoo HTTP | container; host loopback map | NOT public | ERP docker / exposure gates |
| 8071 | policy watch | not published | BLOCKED | policy |
| 8072 | gevent classic | not published | BLOCKED | policy |
| 5432 | PostgreSQL | docker internal | NEVER public | database provision |
| 10000 | Webmin preexisting | not opened by Soviez | detect only | management_surface |
