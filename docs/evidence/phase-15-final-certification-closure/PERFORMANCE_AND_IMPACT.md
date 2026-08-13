# Performance and Impact

- Production remains serving during candidate upgrade (downtime limited to switch window)
- Colima reboot batch: single shared VM restart for multi-checkpoint reconcile (cert only)
- Image cleanup: dry-run cheap; deletes are exact, sequential, TOCTOU-checked
- Shared layers: reclaim may be less than sum of image sizes
- No SaaS/UI/registry product changes in this closure
