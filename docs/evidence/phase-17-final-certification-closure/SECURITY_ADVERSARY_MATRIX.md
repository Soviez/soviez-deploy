# SECURITY_ADVERSARY_MATRIX.md

| Adversary | Result |
|-----------|--------|
| Unsigned / mutable `latest` installer | DENIED |
| Bad digest / bad signature / untrusted signer | DENIED |
| Bootstrap code replay | DENIED |
| Wrong License / source / destination | DENIED |
| mTLS CA substitution | DENIED |
| Cross-tenant discovery/pairing/report leakage | DENIED |
| Payload transfer authorization | DENIED |
| Token reserve/consume in Phase 17 | DENIED |
| Secret leakage in reports/logs | DENIED |
| Silent trust after reboot | DENIED (`recovery_required`) |
