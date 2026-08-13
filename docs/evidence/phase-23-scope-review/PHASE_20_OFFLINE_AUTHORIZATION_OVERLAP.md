# PHASE_20_OFFLINE_AUTHORIZATION_OVERLAP

Existing: `soviez.migration_authorization_offline_package.v1` with package_id, authorization_id, public_signature, ledger offline-register.

Boundary: distinct from update bundles (`soviez.offline_update_bundle.v1`). Reuse pairing of package+auth IDs and replay concept only.
