# CAPABILITY_MATRIX — Phase 10 Stage License

| Capability | Scope | Mapping source | Resolver |
|------------|-------|----------------|----------|
| `stage_environments` | exact `license_id` | `addon_slug: stage-license-monthly` | `stage_license_resolve` |
| `stage_environments` | exact `license_id` | `grant_type: stage_license` | `stage_license_resolve` |

Cross-license: entitlement on License A does **not** cover License B.
