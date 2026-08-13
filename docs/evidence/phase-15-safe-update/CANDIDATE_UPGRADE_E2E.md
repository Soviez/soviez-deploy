# Candidate upgrade E2E
- File-level candidate DB/filestore clone from recovery set
- Test-mode upgrade writes running_digest + modules_updated; sets live_production_mutated=false
- When local Postgres available: creates disposable `upd_*` DB and inserts digest marker (not live Production DB)
- Full containerized ERP image `-u` blocked by Docker daemon absence → PARTIAL
