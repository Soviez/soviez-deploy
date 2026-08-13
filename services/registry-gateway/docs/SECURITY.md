# Security — Soviez Registry Gateway

## Trust model

1. Clients present short-lived **Soviez pull tickets** (Ed25519, domain `soviez.registry-pull-ticket.v1`).
2. Gateway verifies tickets **offline** using configured public keys.
3. Only the ticket-bound repository + digest graph is proxied upstream.
4. Upstream Hub Basic auth stays on the gateway host and is **never returned to clients**.

## Hard requirements

- No real secrets in git, package artifacts, or example files (placeholders only).
- No `docker.sock` mount; container runs non-root; capabilities dropped.
- Do not run the gateway privileged or on host network unless an approved exception exists.
- TLS at the edge (`registry.soviez.com` / `registry-staging.soviez.com`); prefer loopback-only Node bind.
- Push/delete/catalog/tag listing are denied in application code.

## Secrets placement

| Secret | Where |
|--------|--------|
| Hub user/token | `/etc/soviez-registry-gateway/gateway.env` on gateway host only |
| Ticket **public** keys | Same env file (`SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON`) |
| Ticket **private** keys | Issuer / control plane secret store (not in this package) |
| TLS private keys | Host cert paths referenced by nginx (not in repo) |

## Logging & redaction

Upstream tokens must never be logged. Use package helpers in `src/redact.ts`. Treat access logs as sensitive if Authorization headers are captured at the proxy — prefer omitting them.

## Host hygiene

- File mode `640` (or stricter) on `gateway.env`
- Restrict SSH and sudo to registry operators
- Installer does not open broad firewall holes or reset ufw/nftables policies
- No Webmin/Virtualmin dependency or install path

## Disclosure

If credentials may have leaked from an operator workstation or misconfigured proxy, rotate Hub PAT and ticket signing keys, update the public key map, and invalidate outstanding tickets (short TTL limits blast radius).
