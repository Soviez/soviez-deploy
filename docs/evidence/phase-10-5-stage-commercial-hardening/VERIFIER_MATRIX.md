# VERIFIER_MATRIX — Phase 10.5

| Check | Location | Failure code (examples) |
|-------|----------|-------------------------|
| Malformed token | helper + SaaS | `TICKET_SIGNATURE_INVALID` |
| Wrong typ / protocol | helper | `TICKET_SIGNATURE_INVALID` |
| Unknown key id | helper | `TICKET_SIGNATURE_INVALID` |
| Bad signature | helper | `TICKET_SIGNATURE_INVALID` |
| exp ≤ now | helper | `TICKET_EXPIRED` |
| Binding mismatch | `assertBindings` | field-specific codes |
| Ledger reuse | helper ledger | `OFFLINE_PACKAGE_ALREADY_USED` |
| Neutralization incomplete | helper | `NEUTRALIZATION_FAILED` |

Helper: Node TypeScript — **not** Bash-only (`services/stage-operation-helper`).

**Tests:** _(parent fills)_
