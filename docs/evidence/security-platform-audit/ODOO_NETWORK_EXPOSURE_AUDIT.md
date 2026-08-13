# Odoo network exposure audit

```text
docker run -p "${SOVIEZ_HOST_PORT}:8069"
```
= publish on **all interfaces** (`0.0.0.0`), not `127.0.0.1:${port}:8069`.

Nginx correctly proxies to `127.0.0.1:${host_port}`, but that does not prevent direct hits to `${host_port}` if firewall/Docker allows.

Staging in `soviez-sh` uses `--http-interface=0.0.0.0` **inside** container without host publish by default (comment says internal only) — better for staging if no `-p`.

Future acceptable: `127.0.0.1:${port}:8069` or proxy-only private network.
