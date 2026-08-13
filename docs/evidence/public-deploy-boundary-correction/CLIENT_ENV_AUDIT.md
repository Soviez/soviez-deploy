# CLIENT_ENV_AUDIT

## Allowed (public/client)

- `SOVIEZ_REGISTRY_GATEWAY_URL`
- Ticket/SaaS endpoints via existing SaaS client config
- Expected repository/digest from release metadata
- Short-lived `SOVIEZ_REGISTRY_PASSWORD` from ticket exchange

## Disallowed on client (confirmed absent from customer examples after correction)

- `SOVIEZ_UPSTREAM_REGISTRY_USER` / `SOVIEZ_UPSTREAM_REGISTRY_TOKEN`
- Gateway signing private keys
- Internal server secrets under `/etc/soviez-registry-gateway`

CLIENT_ENV_AUDIT = PASS
Upstream Hub credentials in public tree: **NO** (placeholders only, and those files removed)
Signing private keys in public tree: **NO**
