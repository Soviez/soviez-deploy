# S3 exact deletion
- `soviez_backup_s3_dest_delete_exact` deletes one object key only
- Static gate fails `aws s3 rm --recursive`, `mc rm --recursive`, `rclone purge`
- Retention cleanup invokes exact object deletes then exact local backup dir
