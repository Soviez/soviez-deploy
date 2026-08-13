# MIGRATION_AUTHORIZATION_OBJECT

## Design (known)

Schema: `soviez.migration_authorization.v1`

Required fields include: authorization_id, idempotency_key, request_hash, token quantities before/after, source/dest fingerprints, stage_rebind_results, source_grace_state=`migration_origin_grace`, destination_status=`production_licensed_pre_cutover`, hard false flags for phase21/DNS/cutover.

Fixture signer: `soviez-p20-fixture-ledger`.

## Certification

**Result:** Pending certification run
