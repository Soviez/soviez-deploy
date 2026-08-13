# STAGE_ORIGIN_CERTIFICATE — Phase 10.5

Type: `soviez.stage-origin-certificate.v1`

| Property | Behavior |
|----------|----------|
| Storage | Local file (helper `writeOriginCertificateFile`) |
| Phone-home | **None** |
| Survives Stage License expiry | **Yes** |
| Contains business data | **No** |
| Retention fields | May be null until Phase 13 |
| Ties to | stage_id, license_id, FP, DB UUID, digests, neutralization_digest, delivery_trace_id, ticket_jti |

**Tests:** _(parent fills)_
