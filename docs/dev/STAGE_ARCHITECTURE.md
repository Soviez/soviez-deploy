# Stage Architecture

- Retention constants: `SOVIEZ_RETENTION_DEFAULT_DAYS=14`, `MAXIMUM=60` (`src/stage/retention_codes.sh`)
- Immutable original creation time anchors max lifetime
- Entitlement expiry: create denied; existing lifecycle continues (`src/stage/lifecycle.sh`, CLI help)
- Final backup + Safe Shield on retention deletion
- Offline Stage: `commands/stage_offline.sh` blocks SaaS phone-home
