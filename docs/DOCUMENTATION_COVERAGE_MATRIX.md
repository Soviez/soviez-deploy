# Documentation Coverage Matrix

| Capability | Code owner | Test owner | User docs | Dev docs | AI docs | Status |
| ---------- | ---------- | ---------- | --------- | -------- | ------- | ------ |
| clean install | Soviez ERP/soviez.sh --init/--new | tests/security/s6 + integration | docs/user/INSTALLATION.md | docs/dev/INSTALLER_ARCHITECTURE.md | docs/ai/CURRENT_STATE.md | DOCUMENTED |
| --init | Soviez ERP/soviez.sh | wizard + security guests | docs/user/INITIALIZATION.md | docs/dev/INSTALLER_ARCHITECTURE.md | docs/ai/IMPLEMENTATION_INVARIANTS.md | DOCUMENTED |
| --new | wizard + src/commands/new.sh | integration/new suites | docs/user/NEW_PRODUCTION.md | docs/dev/CLI_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| --stage | src/stage, commands/stage* | stage integration | docs/user/STAGE_ENVIRONMENTS.md | docs/dev/STAGE_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| --update | src/update | update final cert | docs/user/UPDATES.md | docs/dev/UPDATE_ENGINE.md | docs/ai | DOCUMENTED |
| --merge-in | (absent) | phase-17 evidence | docs/user/CLI_REFERENCE.md | docs/dev/MIGRATION_ARCHITECTURE.md | docs/ai/FORBIDDEN_ACTIONS.md | NOT_SUPPORTED |
| backup | src/backup | backup tests + S5 | docs/user/BACKUP.md | docs/dev/BACKUP_RESTORE_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| restore | src/restore | restore + S4 | docs/user/RESTORE.md | docs/dev/BACKUP_RESTORE_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| offline update | src/offline_* | phase23 | docs/user/OFFLINE_UPDATES.md | docs/dev/OFFLINE_UPDATE_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| migration | src/migration | phase17-22 | docs/user/MIGRATION.md | docs/dev/MIGRATION_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| Stage expiry | src/stage/retention* | stage retention tests | docs/user/STAGE_ENVIRONMENTS.md | docs/dev/STAGE_ARCHITECTURE.md | docs/ai/IMPLEMENTATION_INVARIANTS.md | DOCUMENTED |
| licensing | src/license,entitlement,saas | saas suites | docs/user/LICENSING.md | docs/dev/LICENSING_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| activation | commands/new | phase8 | docs/user/ACTIVATION.md | docs/dev | docs/ai | DOCUMENTED |
| network | security/platform firewall/docker | S1/S2 | docs/user/NETWORKING.md | docs/dev/NETWORK_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| TLS | src/ssl + wizard | ssl e2e | docs/user/DOMAIN_AND_TLS.md | docs/dev | docs/ai | DOCUMENTED |
| WebSocket | ERP write_nginx_site + S2 nginx_edge | S2 template tests | docs/user/WEBSOCKET_AND_LONGPOLLING.md | docs/dev/WEBSOCKET_LONGPOLLING_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| longpolling | S2 nginx_edge (same upstream) | S2 | docs/user/WEBSOCKET_AND_LONGPOLLING.md | docs/dev/WEBSOCKET_LONGPOLLING_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| security scanning | security/detection | S3 | docs/user/SECURITY.md | docs/dev/SECURITY_SCANNER.md | docs/ai/SECURITY_INVARIANTS.md | DOCUMENTED |
| quarantine | security/quarantine | S4 | docs/user/RESTORE.md | docs/dev/QUARANTINE_ARCHITECTURE.md | docs/ai | DOCUMENTED |
| diagnostics | ops/operations | ops tests | docs/user/STATUS_AND_DIAGNOSTICS.md | docs/dev/OPERATION_ENGINE.md | docs/ai | DOCUMENTED |
| recovery | *-recover commands | integration | docs/user/RECOVERY.md | docs/dev/FAILURE_AND_ROLLBACK.md | docs/ai | DOCUMENTED |
| apt-lock safety | update_safety/apt_lock.sh | S5 corr | docs/user/UPDATES.md | docs/dev/UPDATE_ENGINE.md | docs/ai/IMPLEMENTATION_INVARIANTS.md | DOCUMENTED |
| Webmin never install | management_surface detect-only | S2 webmin detect | docs/user/SECURITY.md | docs/security/WEBMIN_VIRTUALMIN.md | docs/ai/IMPLEMENTATION_INVARIANTS.md | DOCUMENTED |
