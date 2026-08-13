# SECURITY_THREAT_MODEL.md

| Threat | Impact | Mitigation in Phase 24 scope |
|--------|--------|------------------------------|
| Scope escalation into live production | Customer outage / data loss | Explicit exclusions; no rollout commands |
| Certified-state regression | Break P15–P23 | Reuse owners; regression suites |
| Bypass of signed update | Malicious installer/image | Fail-closed STRICT_SIG; ban fake sigs |
| Stale readiness treated as auth | Premature Phase 24/25 | Readiness informational; OD required |
| Artifact substitution / wrong SHA | False PASS | Pin SHA; checksum tests |
| Cross-tenant target | Wrong License hit | Exact targeting tests |
| Hidden phone-home regression | Sovereignty breach | Static + runtime egress tests |
| Registry credential leakage | Image theft / account abuse | Ephemeral docker config; CI scan |
| Signing-key leakage | Forge bundles | Secret scan; no keys in dist |
| Backup deletion via “cleanup” | Data loss | Forbid destructive cleanup |
| Source purge aliased as hardening | Irreversible destroy | Purge out of scope |
| License/slot mutation | Accounting break | No slot product in P24 |
| Evidence tamper / false PASS | Bad release | Atomic finalizer patterns; suite |
| Skipped material suites | Hollow PASS | Cert mode fail-closed |
| service-role credentials in dist | SaaS compromise | Scan + acceptance clarify |
| Malicious Root on host | Host takeover | Document residual Root boundary (honest) |
| Soft docker config residue | Cred reuse | Fail-closed lockdown |
| Test flags left enabled in prod | Unsigned paths | Gate behind TEST_MODE only |

Residual: privileged host Root can always bypass local controls — document, do not pretend otherwise.
