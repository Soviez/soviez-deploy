# BACKUP_DESTINATION_CLASSIFICATION

`soviez_s5_backup_classify_destination`:

| Class | Meaning |
|-------|---------|
| `LOCAL_ONLY` | On-host only |
| `OFF_HOST_S3_COMPATIBLE` | Customer S3/MinIO/R2-style |
| `OFF_HOST_SFTP` | Customer SFTP/SSH |

**LOCAL_ONLY ≠ DR-capable** (`soviez_s5_backup_dr_capable` → false; `SEC_HIGH_BACKUP_LOCAL_ONLY` if DR falsely claimed). PASS.
