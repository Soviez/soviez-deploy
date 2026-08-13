# Forbidden operation static gate
- Scans src/backup, src/restore, dist/soviez.sh
- Blocks recursive S3/SFTP wipes, StrictHostKeyChecking=no, docker prune variants
- Test: `tests/security/test_phase16_forbidden_operations.sh` PASS
