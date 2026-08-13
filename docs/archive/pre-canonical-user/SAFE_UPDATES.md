# Safe Updates

Annual Support & Updates is required for product updates. The legacy monthly technical support plan does **not** include updates.

Always select one exact Production instance. The installer never updates all tenants by default.

Before changes, Soviez runs preflight checks (disk, identity, addons). A disposable update candidate is prepared and upgraded while your current Production keeps running. Switch happens only after validation and confirmation. Expected downtime is limited to the short switch window.

If something fails before or during switch, rollback restores the previous runtime. Support expiry after a successful install never stops the running ERP. Business data is not uploaded to Soviez SaaS. Local `--update-status` shows progress and rollback availability. Connected and offline (signed package) paths are supported.

After a successful update, Soviez keeps the previous image for about 24 hours so rollback remains possible. Later, unused managed images may be cleaned up carefully — never with a broad Docker prune. See `UPDATE_IMAGE_CLEANUP.md`.
