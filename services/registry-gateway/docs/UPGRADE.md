# Upgrade — Soviez Registry Gateway

## Standard path

From the new package directory (extracted release or git checkout):

```bash
sudo ./update.sh
```

`update.sh` delegates to `install.sh`, which:

1. Snapshots the current `/opt/soviez-registry-gateway` tree
2. Copies the new package over the install root
3. Preserves `/etc/soviez-registry-gateway/gateway.env`
4. Rebuilds/recreates the Compose service
5. Runs `healthcheck.sh`
6. On failure, rolls back from the snapshot (see [RECOVERY.md](RECOVERY.md))

## Version file

`VERSION` in the package root records the gateway package version (`0.1.0` for this publication cycle). Platform installer versions (e.g. soviez.sh `0.24.5.x`) are separate; keep gateway docs aligned when cutting a joint release.

## Config migrations

- New env vars appear in `.env.example` / `config/gateway.env.example`
- Merges are **manual** — install never overwrites a live `gateway.env`
- Diff examples against production carefully; do not paste real secrets into tickets or chat

## nginx template updates

`install.sh` refreshes `/etc/nginx/sites-available/registry.soviez.com.conf` from the package. Re-apply local cert path edits if the template was customized, then `nginx -t && systemctl reload nginx`.

## Rollback after a successful but unwanted upgrade

```bash
# Identify snapshot
ls /var/lib/soviez-registry-gateway/backups/

# Restore tree (example)
sudo rsync -a --delete \
  /var/lib/soviez-registry-gateway/backups/pre-install-STAMP/tree/ \
  /opt/soviez-registry-gateway/

# Restore env if captured
sudo cp -a /var/lib/soviez-registry-gateway/backups/pre-install-STAMP/gateway.env \
  /etc/soviez-registry-gateway/gateway.env

cd /opt/soviez-registry-gateway
sudo docker compose -f compose.yml up -d --build --remove-orphans
sudo ./healthcheck.sh
```
