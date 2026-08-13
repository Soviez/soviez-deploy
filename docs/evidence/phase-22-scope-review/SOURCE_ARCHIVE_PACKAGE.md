# Source Archive Package

Canonical fields (schema `soviez.source_archive.v1`):

- schema_version, archive_id, operation_id
- license_id, migration_authorization_id, cutover_operation_id
- source_production_id, source_environment_id, source_device_fingerprint
- source_database_uuid, source_image_digest, final_source_state, traffic_owner
- database_archive_ref + checksum
- filestore_archive_ref + checksum
- addon_manifest, configuration_manifest, secret_inventory (no cleartext secrets)
- backup_references, certificate_public_fingerprints, dns_rollback_snapshot
- stage_archive_references, infrastructure_inventory, host/provider metadata
- retention_policy, created_timestamp, verification_timestamp, restore_test_status
- signer, signature, warnings, blockers
- `purge_authorized=false`, `deletion_performed=false`

Never place private credentials or keys in cleartext manifests.
