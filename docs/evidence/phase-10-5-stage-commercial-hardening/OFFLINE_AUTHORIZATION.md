# OFFLINE_AUTHORIZATION — Phase 10.5

| Step | Component |
|------|-----------|
| Issue package | POST `.../offline/package` → `soviez.stage-offline-auth.v1` |
| Verify | Helper `verifyStageOperationTicket` + bindings |
| Consume once | Local ledger (`consumeOnce`) |
| Residual | Root can rewrite ledger / replace helper |

Online path remain primary for connected hosts. Offline is first-class for air-gap, not a kill-switch.

**Tests:** _(parent fills)_
