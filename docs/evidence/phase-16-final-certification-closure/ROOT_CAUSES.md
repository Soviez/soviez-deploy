# Root causes closed
1. S3 path short-circuited to filesystem fixture under TEST_MODE
2. SFTP path short-circuited to filesystem fixture; mkdir batch aborted on existing parent
3. Restore-test used erp.started markers instead of real ERP /web/login
4. Reboot evidence used process/op-state only, not Colima VM stop/start
5. Transfer failures hidden by `cmd | tail` without pipefail
