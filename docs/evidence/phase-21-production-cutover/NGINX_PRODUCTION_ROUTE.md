# NGINX_PRODUCTION_ROUTE — Phase 21

**Status:** STUB

## Design facts tested

- Exact `server_name` for Production FQDN
- `soviez_migration_p21_nginx_validate_no_wildcard` rejects `server_name *`
- Destination route under `nginx_sites_p21/destination/production.conf`
- Source maintenance under `nginx_sites_p21/source/maintenance.conf`

## Evidence to attach

- [ ] Production conf excerpt (redacted cert paths)
- [ ] Wildcard rejection error code
