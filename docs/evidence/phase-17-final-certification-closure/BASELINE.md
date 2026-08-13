# Baseline — Phase 17 Final Certification Closure

**Date:** 2026-08-01  
**Primary repo:** `/Volumes/PortableSSD/soviez-project/soviez-sh`  
**Git:** no commits yet on `main` (dirty working tree preserved; no commit authorized)  
**SaaS ref HEAD:** `2f2f13c655ac42aa976764db56d939bf60a40094`

## Certified state before closure

```text
Phase 16 = PASS
Phase 17 = PARTIAL
Progress = 84%
Weight 5 = uncredited
Installer = 0.17.0-phase17
Phase 18 = UNAUTHORIZED
```

## Reference repositories (read-only)

- `/Volumes/PortableSSD/soviez-project/soviez-saas`
- `/Volumes/PortableSSD/soviez-project/Soviez ERP`
- Legacy: `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh`

## Binding invariants (must remain true)

```text
data_transfer_started=false
migration_token_consumed=false
migration_token_reserved=false
source_maintenance_enabled=false
dns_changed=false
final_migration_certificate_issued=false
destination_production_activated=false
source_license_active=true
source_runtime_active=true
```
