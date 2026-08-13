# Operation Engine Model

## Proposed operations

- `migration_stabilization_validate`
- `migration_rollback_window_close`
- `migration_source_archive_plan`
- `migration_source_archive_create`
- `migration_source_archive_verify`
- `migration_source_license_finalize`
- `migration_source_runtime_suspend`
- `migration_stage_source_archive`
- `migration_retirement_readiness`
- `migration_phase23_readiness`

## Happy-path states

```text
created
→ validating_phase21
→ observing_stabilization
→ validating_destination_sustained_health
→ validating_backups
→ awaiting_rollback_window_closure
→ closing_rollback_window
→ inventorying_source
→ preparing_archive
→ creating_database_archive
→ creating_filestore_archive
→ creating_manifests
→ verifying_archive
→ restore_testing_archive
→ finalizing_source_license
→ disabling_source_integrations
→ suspending_source_runtime
→ validating_source_quarantine
→ archiving_source_stages
→ producing_retirement_readiness
→ producing_phase23_readiness
→ completed
```

## Failure / recovery states

- `stabilization_failed`
- `rollback_window_still_required`
- `archive_preparation_failed`
- `archive_creation_failed`
- `archive_verification_failed`
- `restore_test_failed`
- `source_license_finalize_failed`
- `source_runtime_suspend_failed`
- `credential_disposition_incomplete`
- `stage_archive_partial`
- `recovery_required`
- `manual_intervention_required`
- `failed_terminal`

**No destructive terminal state in Phase 22.**
