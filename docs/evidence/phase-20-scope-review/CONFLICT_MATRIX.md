# CONFLICT_MATRIX.md

Exact locks (minimum):

```text
one active License-binding transition per License
one active token-consumption transaction per entitlement
one active destination activation per migration pair
```

Conflicts (deny / serialize):

- Another Phase 20 auth for same License
- Another migration for same source / another destination binding
- Source update / restore-to-new / reauthorization
- Destination cleanup / Phase 19 rerun mid-flight
- Phase 18 Abort after Phase 20 commit (local apply still owns recovery)
- Stage clone/refresh/delete conflicting with rebind
- License purchase/refund/dispute mutating same entitlement mid-commit
- Manual admin binding edit
- Phase 21 cutover while Phase 20 recovery open
- Source purge/archive
- Token refund/revoke mid-flight
- Destination restore conflicting bind
- Production slot transfer / device replacement
