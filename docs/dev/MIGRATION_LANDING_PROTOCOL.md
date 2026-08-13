# Migration Landing Protocol

Commands:

- `sudo soviez.sh --migration-landing-prepare <pair-id>`
- `sudo soviez.sh --migration-landing-status <operation-id>`
- `sudo soviez.sh --migration-landing-cleanup <pair-id>`

## Rules

- Temporary nginx site bound to **migration FQDN only**
- Must never `server_name` the Production domain
- Neutral English maintenance content + security headers + `/healthz`
- Public exposure allowed only after DNS ownership + TLS path
- Abort / cleanup removes destination landing artifacts

## Non-goals

Does not enable source maintenance pages or Production cutover.
