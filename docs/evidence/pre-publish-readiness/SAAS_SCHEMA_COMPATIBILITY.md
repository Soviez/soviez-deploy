# SAAS_SCHEMA_COMPATIBILITY

## Migrations involved
078–090 (see SAAS_PUBLICATION_SCOPE.md). Not applied by this audit.

## Clean install
New SaaS DB applying full migration chain including 078–090: **SUPPORTED** (designed foundation migrations).

## Upgrade
Existing SaaS must apply 078–090 in order before relying on new installer Stage/migration/offline/registry ticket features.

## Cross-version answers

| Question | Answer |
|----------|--------|
| Can **new installer** talk to **old SaaS** (pre-078)? | **NO / UNSAFE** for Stage entitlement, device/slot, registry pull tickets, migration authorization, offline bundles |
| Can **old installer** talk to **new SaaS** (post-090)? | **LIKELY YES** if APIs remain additive; no evidence of hard break for legacy activation paths — still smoke-test |

## Deployment ordering
1. Deploy SaaS backend + migrations 078–090 (staging first)
2. Smoke installer-auth + entitlement endpoints
3. Publish/install new soviez-sh + wizards
