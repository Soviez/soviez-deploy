# Recovery — Soviez Registry Gateway

## Install / update failure (automatic)

`install.sh` sets an `ERR` trap. On failure it:

1. Reads `/var/lib/soviez-registry-gateway/last-snapshot`
2. Restores the snapshotted install tree
3. Restores `gateway.env` when present in the snapshot
4. Attempts `docker compose up -d`

If no snapshot exists (first install), the trap leaves partial state for inspection and points here.

## Manual restore

```bash
SNAP=/var/lib/soviez-registry-gateway/backups/pre-install-YYYYMMDDTHHMMSSZ
sudo rsync -a --delete "$SNAP/tree/" /opt/soviez-registry-gateway/
[[ -f "$SNAP/gateway.env" ]] && sudo cp -a "$SNAP/gateway.env" /etc/soviez-registry-gateway/gateway.env
cd /opt/soviez-registry-gateway
sudo docker compose -f compose.yml up -d --remove-orphans
sudo ./healthcheck.sh
```

## Lost configuration

Examples live in the package:

- `.env.example`
- `config/gateway.env.example`

Recreate `/etc/soviez-registry-gateway/gateway.env` from backups or a secure secret store. **Rotate** Hub tokens and ticket keys if recovery media may have been exposed.

## Container / image corruption

```bash
cd /opt/soviez-registry-gateway
sudo docker compose -f compose.yml down
sudo docker compose -f compose.yml build --no-cache
sudo docker compose -f compose.yml up -d
sudo ./healthcheck.sh
```

## Complete reinstall

```bash
sudo ./uninstall.sh          # keeps config + state
# or: sudo ./uninstall.sh --purge
sudo ./install.sh
```

## Data loss expectations

This gateway is stateless aside from in-memory session digest graphs. There is no persistent registry blob store on the host — recovery focuses on **code + config + credentials**, not layer data.

## Escalation checklist

- [ ] `/live` and `/ready` respond locally
- [ ] nginx TLS valid for `registry.soviez.com` or staging
- [ ] Ticket public keys loaded
- [ ] Hub credentials valid and host-local only
- [ ] No secrets committed to git during recovery
