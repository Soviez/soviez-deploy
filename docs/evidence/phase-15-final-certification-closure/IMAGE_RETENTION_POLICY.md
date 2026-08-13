# Image Retention Policy

- Default safety window: **24 hours** after switch (`SOVIEZ_UPDATE_SAFETY_WINDOW_HOURS`)
- Always retain **current** and **rollback** digests for the Production
- Never run broad `docker system prune` / `image prune -a`
- Delete only images classified `eligible_for_cleanup` after reference + ownership + TOCTOU checks
- Operation type: `update_image_cleanup` (Phase 14 adapter)
- Scheduled cleanup may be **superseded** by a new `production_update` on the same env
