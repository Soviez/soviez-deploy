# Backup Retention

By default Soviez keeps a useful mix of Production backups:

- About **7** daily
- About **4** weekly
- About **12** monthly

Pinned backups are never removed by automatic cleanup. You can pin important points before cleanup runs.

```bash
sudo soviez.sh --backup-pin <backup-id>
sudo soviez.sh --backup-unpin <backup-id>
sudo soviez.sh --backup-retention-status [--production ID]
sudo soviez.sh --backup-retention-cleanup [--production ID] [--dry-run] [--confirm]
sudo soviez.sh --backup-delete <backup-id> [--dry-run] [--confirm]
```

Scheduled backups default to **02:00** in the server’s local timezone.

```bash
sudo soviez.sh --backup-schedule-add <production-id> [--destination PROFILE]
sudo soviez.sh --backup-schedule-list
```

Stage environment retention (14–60 days) is a separate feature and does not replace Production backup retention.
