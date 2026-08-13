# BUNDLE_AUTHORIZATION_MODEL

Signed object includes: authorization_id, account_id, license_id, entitlement_grant_ids, target_environment_id, target_device_fingerprint, current/target digests, bundle_id, bundle_type, issuance_reason, not_before, expiry, max_apply_count, replay_policy, revocation_status_at_issuance, signer, signature, reconciliation_requirement, offline_apply_allowed=true, network_required_during_apply=false.

Targeting: A License-only; B License+environment; **C License+environment+Device (recommended)** with separate hardware-replacement reissue path.
