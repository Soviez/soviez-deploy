# Restore and Recovery

Restore always targets one Production and one backup ID. Soviez restores into an isolated candidate, checks it, then switches only after confirmation. If the switch fails, rollback returns you to the previous runtime when possible.

After a successful restore, a **24-hour** safety window keeps rollback available.

```bash
sudo soviez.sh --backup-verify <backup-id>
sudo soviez.sh --restore-test <backup-id>
sudo soviez.sh --restore <production-id> --backup <backup-id> [--confirm]
sudo soviez.sh --restore-rollback <operation-id> [--confirm]
sudo soviez.sh --restore-recover <operation-id>
```

## Limits
- Same host only — backups from another server are rejected for Production restore
- Prefer verified Full backups
- Cross-host migration is not this feature

Optional: restore a backup into a Stage (`--restore-as-stage`) when Stage rules allow, without replacing Production.

Export/import packages for offline media you control:

```bash
sudo soviez.sh --backup-export <backup-id> --output PATH
sudo soviez.sh --backup-import PATH [--confirm]
```
