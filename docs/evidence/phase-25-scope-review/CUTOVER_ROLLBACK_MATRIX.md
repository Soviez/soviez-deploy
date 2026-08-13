# Cutover / rollback matrix

- Traffic ownership transitions recorded
- DNS transition + health validation
- Immediate rollback path
- Rollback window semantics (P22)
- Failure: cutover health fail → no silent ownership lie
- Reboot during migration/cutover recovery where already owned

Runtime: REAL_NETWORK + REAL_ODOO; aggregate prior proofs insufficient alone — at least one full E2E-08 in Phase 25.
