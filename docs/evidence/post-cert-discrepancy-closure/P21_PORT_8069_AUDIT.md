# P21_PORT_8069_AUDIT

Prior: hardcoded 127.0.0.1:8069 (unsafe vs HOST_PORT 8073+).
Now: soviez_migration_p21_resolve_upstream — explicit / SOVIEZ_MIG_P21_UPSTREAM / SOVIEZ_HOST_PORT / docker publish / fallback 8069.
Classification: EXPECTED_BACKEND_HTTP_PORT on host loopback mapping of container 8069.
