# ROLLBACK_AND_RECOVERY_MODEL

Cover pre-mutation abort; candidate/migration/validation/switch/post-switch failures; reboot; power loss; disk-full; corrupt import; receipt loss.

Invariants: Production unchanged before switch; rollback image+backup available; failed candidate ≠ Production; reboot-survivable; idempotent resume; no second entitlement usage; no duplicate receipt; no online dependency for recovery.
