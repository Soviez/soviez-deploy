# TICKET_SCHEMA — Phase 10.5

Canonical claims mirror `StageOperationTicketClaims` in:

- `soviez-saas/src/lib/stage-operation/ticket.ts`
- `soviez-sh/services/stage-operation-helper/src/ticket.ts`

| Field | Required |
|-------|----------|
| typ, protocol_version, jti | yes |
| operation_id, operation_type | yes |
| subject_pseudonym, account_id, license_id | yes |
| device_id, device_pubkey_fingerprint, host_pubkey_fingerprint | yes |
| production_fingerprint, database_uuid | yes |
| stage_id, stage_domain | yes |
| release_id, release_digest | yes |
| tooling_artifact_id, tooling_digest | yes |
| architecture, entitlement_decision_ref | yes |
| delivery_trace_id | yes |
| iat, exp, nonce, signer_key_id | yes |

Signing: domain `soviez.stage-operation.v1` + canonical JSON.

**Tests:** _(parent fills)_
