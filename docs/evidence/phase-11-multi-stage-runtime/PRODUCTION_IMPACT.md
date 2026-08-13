# PRODUCTION_IMPACT

| Risk | Mitigation | Status |
|------|------------|--------|
| DB mutation during snapshot | pg_dump only | ✅ |
| Filestore mutation | checksum compare | ✅ |
| Shared network | per-stage network | ✅ |
| Drop collateral | owned resources only | ✅ |

