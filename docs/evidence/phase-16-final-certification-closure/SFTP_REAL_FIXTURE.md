# SFTP real fixture
- Image: `soviez-p16-sftp:local` (Alpine 3.20 OpenSSH, arm64)
- Port 2222; user `backup`; remote base `/srv/backups`
- Key auth + pinned UserKnownHostsFile; StrictHostKeyChecking=yes
- Test: `tests/integration/test_backup_sftp_real.sh` PASS
