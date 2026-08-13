# Image Cleanup Dry Run

`soviez_image_cleanup_dry_run` returns `IMAGE_CLEANUP_DRY_RUN` JSON with:
- `current_digest` / `rollback_digest`
- `eligible[]` / `protected[]`
- counts only — **no** Docker deletes

Static forbidden-prune gate runs first.
Final cert asserted dry-run code and current/rollback protection.
