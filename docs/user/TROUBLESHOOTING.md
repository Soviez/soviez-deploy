# Troubleshooting

For each item: symptom → cause → safe diagnostics → remediation → escalate.

## Installation failed

- Check Ubuntu version/arch, root, disk, apt lock wait messages
- Re-run `--init`; do not `killall apt`

## Domain not resolving / TLS error

- DNS A record; `nginx -t`; `--ssl-status`; Certbot logs

## Odoo inaccessible

- Nginx 443; loopback publish; container health; **do not** open 8069 public

## DB inaccessible

- Docker network; never publish 5432; check app role (not superuser)

## WebSocket / notifications broken

- See [WEBSOCKET_AND_LONGPOLLING.md](WEBSOCKET_AND_LONGPOLLING.md)
- Verify `/websocket` location and upgrade map
- Do not publish 8072

## PDF 504

- wkhtmltopdf in image; timeouts; see [PDF_REPORTING.md](PDF_REPORTING.md)

## Update failed / rollback

- `--update-status`; disk; entitlement; signature; `--security-update-check`

## Needs Action

- Read operation status/logs; complete required operator confirmation; do not ignore Safe Shield

## Apt lock timeout

- Wait for unattended-upgrades/apt; retry; never kill locks

## Backup/restore/quarantine failed

- Integrity; passphrase; `--security-quarantine-status`; do not force promote on FAIL

## Migration paused

- `--migration-status`; transfer pause/resume; DNS try-again; never invent purge

## Security REVIEW/FAIL

- Read report; remediate; do not weaken firewall as default

## SSH hardening deferred

- Ensure console access; review policy; re-run harden intentionally

**Never recommend weakening security as the default fix.**
