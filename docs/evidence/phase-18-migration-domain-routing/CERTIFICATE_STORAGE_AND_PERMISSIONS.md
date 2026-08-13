# CERTIFICATE_STORAGE_AND_PERMISSIONS

Private keys and ACME account material stored under migration TLS storage paths with restrictive permissions (0600-class). Never placed in argv, logs, or SaaS egress.

Revoke/cleanup on domain abort / `--migration-tls-revoke`.
