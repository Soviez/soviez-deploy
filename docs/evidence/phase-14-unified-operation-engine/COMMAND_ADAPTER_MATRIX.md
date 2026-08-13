# Command Adapter Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Adaptation Logic

To avoid duplicating thousands of lines of certified bash and typescript across past phases, Phase 14 implements a command adapter design pattern. The unified CLI and registry interact only with the canonical metadata interface, while execution is mapped to earlier engines via `soviez_ops_adapter_reattach`.

## 2. Adapter Configuration Matrix

| Operation Type | Underlying CLI command | Legacy Engine Code Path | Shared State Mapper |
|---|---|---|---|
| `new` | `action_activate_soviez_license` | `src/operations/*` | `soviez_ops_migrate_legacy_new` |
| `stage_create` | `stage_create_run` | `src/stage/*` | `soviez_ops_migrate_legacy_stage` |
| `ssl_renewal` | `ssl_reattach` / `renew` | `src/ssl/*` | `soviez_ops_migrate_legacy_ssl` |
| `ssl_repair` | `ssl_reattach` / `repair` | `src/ssl/*` | `soviez_ops_migrate_legacy_ssl` |
| `retention_delete`| `retention_retry` / `extend` | `src/stage/retention_*` | `soviez_ops_migrate_legacy_retention` |
