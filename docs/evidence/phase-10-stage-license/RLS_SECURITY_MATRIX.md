# RLS_SECURITY_MATRIX — Phase 10 Stage License

| Table | anon | authenticated | service_role |
|-------|------|---------------|--------------|
| `stage_license_settings` | DENY | SELECT | ALL |
| `stage_license_entitlements` | DENY | SELECT own (`account_id = auth.uid()`) | ALL |
| `stage_license_events` | DENY | SELECT own | ALL |
| `stage_license_quotes` | DENY | SELECT own | ALL |

Certified: anon direct SELECT rejected (permission denied / RLS).
