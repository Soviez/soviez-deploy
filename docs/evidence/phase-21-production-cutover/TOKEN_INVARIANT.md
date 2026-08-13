# TOKEN_INVARIANT — Phase 21

**Status:** STUB

## Design facts tested

- Phase 20 commit consumes token once (`grant_remaining=0`, `slot_count=1`)
- Cutover revalidates consumption; never increments consume
- Rollback returns `token_restored=false`
- Concurrent cutover on same pair cannot double-consume

## Evidence to attach

- [ ] Ledger snapshot before/after cutover
- [ ] Concurrent cutover ledger snapshot
