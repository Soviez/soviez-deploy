# Backup Destinations

Backups always support a **local** destination on your server. You may also send encrypted copies to destinations you control:

- **S3-compatible** object storage
- **SFTP** to your own host (strict host-key checking)

Soviez does not host your backups and does not receive backup files, encryption passphrases, or destination credentials.

```bash
sudo soviez.sh --backup-destination-list
sudo soviez.sh --backup-destination-show <profile-id>
sudo soviez.sh --backup-destination-test <profile-id>
sudo soviez.sh --backup <production-id> --destination <profile-id>
```

Keep passphrases and SFTP/S3 secrets only on the server (or your own secret store). Losing the passphrase means encrypted backups cannot be restored.
