# PHASE19_REVALIDATION.md

Before irreversible commit, revalidate:

- Migration pair valid / unexpired / signatures OK
- Phase 18 routing readiness current
- Phase 19 transfer complete; staging verified; `ready_for_20` ≠ BLOCKED
- Source write freeze **released**; source active + License active
- Source DB UUID unchanged; destination UUID/digest/staging identity match policy
- Selected Stage list final
- No payload drift requiring Phase 19 rerun
- No identity drift; no public destination route
- Token still eligible; no conflicting op; backup pinned; rollback prerequisites valid

Material drift → block Phase 20; require Phase 19 revalidation/rerun.
