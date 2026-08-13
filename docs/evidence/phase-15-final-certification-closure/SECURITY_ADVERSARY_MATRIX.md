# Security Adversary Matrix (Phase 15 Final)

| Adversary goal | Control | Result |
|----------------|---------|--------|
| Burn second license slot via candidate | `license_slot_consumed=false`; no reservation API | Blocked |
| Bypass Guard via env | Bypass env denylist | Blocked |
| Blind replay switch after reboot | Reconcile → `UPDATE_RECOVERY_REQUIRED` | Blocked |
| Broad prune host images | Forbidden prune gate | Blocked |
| Delete current/rollback early | Classification + 24h window | Blocked |
| Delete image used by other Production/Stage | Reference scan | Blocked |
| Persist pull token in state | Short-lived session; credential cleanup marker | Blocked |
| Upload business data to SaaS | Update sovereignty contract | Not performed |

Honest residual: Full Root can replace Guard binary / disable enforcement.
