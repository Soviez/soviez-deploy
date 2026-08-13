# SAAS_DATABASE_TESTS

## Disposable PostgreSQL 16 proof

Script: `soviez-saas/scripts/phase20-disposable-pg-commit-proof.sh`

Stubbed prior schema (`profiles`, `licenses`, `commercial_grants`, enums) then applied forward-only migration `087_migration_authorization_atomic.sql`.

### Proven

- `commit_migration_authorization` commits atomically
- `token_consumed=true`, `quantity_after=0`
- `license_slots_used` unchanged (=1)
- `migration_source_grace` row created
- `migration_binding_transitions` row created
- Idempotent replay returns `idempotent=true` without second consume
- `consume_ip_migration_token` raises redirect to canonical commit
- `phase21_allowed=false`, `production_dns_changed=false`, `traffic_cutover_started=false`

### Result row (certification)

```text
authorizations | consumed | slots | license_wallet | grace_rows
             1 |        1 |     1 |              0 |          1
```

### Notes

- Not deployed to live Supabase
- Frozen SaaS UI not modified
- COMMENT on `begin_license_migration` is conditional (exists-only) so disposable apply does not invent legacy dashboard RPCs
