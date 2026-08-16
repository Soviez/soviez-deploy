# New Production (`--new`)

## Wizard surface

```bash
sudo soviez.sh --new
```

Creates Production ERP: Docker network, PostgreSQL, Odoo container (loopback publish), Nginx vhost, TLS, activation.

## Modular surface

```bash
soviez.sh --new [--domain FQDN] [--activation automatic|manual] [--channel stable]
soviez.sh --reattach <operation-id>
```

Starts a **connected activation operation** tracked by the unified operations engine (survives terminal disconnect).

## Defaults

- `--activation automatic`
- `--channel stable`

## Effects

- Reserves/consumes Production slot per License policy (SaaS)
- Binds Device
- Pulls private image via short-lived Registry credentials when connected
- Configures `proxy_mode = True`, `list_db = False`

## Does NOT

- Expose Odoo 8069 publicly
- Grant PostgreSQL SUPERUSER to the app role
- Require continuous SaaS after activation for ERP runtime
