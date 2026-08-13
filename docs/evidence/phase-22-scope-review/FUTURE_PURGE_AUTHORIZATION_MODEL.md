# Future Purge Authorization Model (NOT implemented in Phase 22)

Even though excluded from Phase 22, define the future model:

- Separate command + operation type + owner authorization
- Exact archive ID + source environment ID + resource manifest
- Typed confirmation phrase + non-TTY approval token
- Recent verified archive + recent restore test
- Destination health current
- Retention eligibility + legal/compliance confirmation
- No active hold / recovery / rollback requirement
- Exact deletion plan preview + irreversible warning
- Per-resource result; failure-safe partial-deletion handling
- No wildcard cleanup / global prune
- Immutable destruction receipt

Forbidden product shapes (even later, without redesign):

```bash
--delete-source
--purge-source
--remove-old-server
--docker-prune
--delete-old-db
```

as generic unscoped commands.

**Phase 22 must leave `MIGRATION_PURGE_NOT_AUTHORIZED` etc. enforced.**
