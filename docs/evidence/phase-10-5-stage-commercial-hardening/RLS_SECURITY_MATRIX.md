# RLS_SECURITY_MATRIX — Phase 10.5

Migration: `086_stage_operation_authorization.sql`.

Expected posture (certify in Docker; parent fills results):

| Role | stage_tooling_artifacts | stage_operation_authorizations | related event/cert tables |
|------|-------------------------|--------------------------------|---------------------------|
| `anon` | deny | deny | deny |
| `authenticated` | read approved public metadata only if granted by policy; no private keys | SELECT own account rows only | own rows only |
| `service_role` | full | full | full |

No client insert of authorizations. No private signing keys in tables.

**Tests:** _(parent fills)_
