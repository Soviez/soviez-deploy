# PRODUCTION_SELECTION

| Check | Result |
|-------|--------|
| Managed Production required | ✅ `NO_MANAGED_PRODUCTION` if absent |
| Health validation | ✅ unhealthy → `PRODUCTION_UNHEALTHY` |
| Identity fields | license_id, fingerprint, database_uuid, tenant |
| Fixture mode | `SOVIEZ_STAGE_FIXTURE_PRODUCTION_JSON` |

Source: `src/stage/production.sh`.
