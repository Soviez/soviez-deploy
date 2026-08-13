# SOURCE_GRACE_MODEL.md

## Options assessed

| Option | Verdict |
|--------|---------|
| A — Immediate source License invalidation | **Reject** — breaks live traffic before Phase 21 |
| B — Temporary dual-runtime with strict anti-split-brain | **Recommend** |
| C — Source fully licensed indefinitely | **Reject** — commercial duplication |

## Recommended state: `migration_origin_grace`

Properties:
- Same original License; **not** a second slot
- May continue serving **current** Production traffic until Phase 21/22 transition
- Signed + exact-operation-bound
- Rollback-safe before cutover

### Allowed
- Serve existing traffic
- Backup / status / diagnostics / recovery reads
- Exact restore-to-self per Phase 16 policy (OD — default allow safety restores; deny restore-to-new-Production)

### Denied
- New Stage creation
- Update switch
- Restore-to-new-Production / clone new Production
- Identity rebind / device reauthorization
- Second migration
- Commercial expansion / License export
- Becoming unrestricted dual Production

### Duration (recommended)

No short automatic expiry that takes down live Production. Grace persists until explicit Phase 21 cutover or Phase 22/admin rollback. Stale migration → Needs Action; not silent unrestrict.
