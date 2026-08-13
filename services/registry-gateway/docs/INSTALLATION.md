# Installation — Soviez Registry Gateway

**Version:** see `VERSION` (package `0.1.0`)  
**OS focus:** Ubuntu 22.04 / 24.04  
**Public hosts:** `registry.soviez.com` (production), `registry-staging.soviez.com` (staging)

## What you get

- Node.js OCI Registry HTTP API V2 **pull** proxy
- Ed25519 offline pull-ticket verification
- Docker Compose + systemd unit
- Optional nginx TLS termination template
- Health probes: `/live`, `/ready`, and `/health` (alias)

Upstream Docker Hub credentials remain **only on the gateway host** and are never returned to clients.

## Prerequisites

- Root shell (`sudo`)
- Docker Engine + Compose plugin (`docker compose`)
- Outbound HTTPS to upstream (`registry-1.docker.io` by default)
- DNS for `registry.soviez.com` / staging pointing at this host
- TLS certificates for nginx (not bundled)

This installer does **not** install Webmin/Virtualmin and does **not** reset firewall policy.

## Quick install

```bash
cd /path/to/soviez-registry-gateway
sudo ./install.sh
```

Idempotent behavior:

- Re-running `install.sh` refreshes `/opt/soviez-registry-gateway` from the package
- Preserves existing `/etc/soviez-registry-gateway/gateway.env` if present
- Snapshots the previous tree under `/var/lib/soviez-registry-gateway/backups/`
- On failure, rolls back from the last snapshot (see [RECOVERY.md](RECOVERY.md))

## Post-install

1. Edit `/etc/soviez-registry-gateway/gateway.env` (from example placeholders).
2. Set ticket public keys and Hub pull credentials (host-local only).
3. `sudo systemctl restart soviez-registry-gateway`
4. `sudo ./healthcheck.sh` (or from install root)
5. Configure TLS: copy `nginx/registry.soviez.com.conf`, replace `CERT_*` placeholders, enable site, `nginx -t && systemctl reload nginx`

## Compose-only (no systemd)

```bash
cp .env.example .env   # edit placeholders
docker compose up -d --build
./healthcheck.sh
```

## Uninstall / update

- Update: `sudo ./update.sh` (snapshots, then reinstall)
- Uninstall: `sudo ./uninstall.sh` (keeps config) or `sudo ./uninstall.sh --purge`

## Rollback on failure

If `install.sh` fails mid-flight, the `ERR` trap restores the last snapshot (code tree + `gateway.env` when captured) and attempts to bring Compose back up. Inspect:

```bash
ls /var/lib/soviez-registry-gateway/backups/
journalctl -u soviez-registry-gateway -e
docker compose -f /opt/soviez-registry-gateway/compose.yml logs --tail=200
```

See [UPGRADE.md](UPGRADE.md) and [RECOVERY.md](RECOVERY.md).
