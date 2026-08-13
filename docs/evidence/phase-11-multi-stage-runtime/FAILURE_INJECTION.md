# FAILURE_INJECTION

| Injection | Expected |
|-----------|----------|
| Duplicate domain | `STAGE_DOMAIN_CONFLICT` exit 20 ✅ unit |
| Expired entitlement | deny create ✅ integration |
| Self-signed SSL | chain validate fail ✅ unit |
| Missing helper | `TOOLING_UNAVAILABLE` |
| Illegal SM transition | `SOVIEZ_ERR_STATE` ✅ unit |

