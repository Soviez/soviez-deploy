# MIGRATION_TOKEN_NON_MUTATION

Phase 18 domain plan / routing / abort objects keep `migration_token_consumed=false` and never call reserve/consume/burn RPCs.

Static gate scans `migration_token_consumed=true` and `begin_license_migration`.
