# REPLAY_MODEL

Track bundle_id, authorization_id, operation_id, apply_count, first_seen, applied_at, result, target fingerprint, manifest digest.

Import/inspect may repeat. Successful apply once per exact environment. Failed pre-mutation does not consume apply. Post-mutation → same operation recover/rollback. No generic fleet-reusable Production bundle initially.
