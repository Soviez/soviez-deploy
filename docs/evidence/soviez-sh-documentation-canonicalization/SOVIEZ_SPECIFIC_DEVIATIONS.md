# Soviez-Specific Blueprint Deviations

Documented in `docs/security/SOVIEZ_PRODUCTION_SECURITY_BLUEPRINT.md` §1–10.

1. **Adaptive workers** — not fixed workers=0-only.
2. **Named release + digest** — not floating `latest`.
3. **PATH CLI** — not repository `dist/` invocation.
4. **Registry Gateway** — internal Soviez service; not customer-deployed.
5. **ClamAV + YARA** — complementary; both in contract baseline.
6. **Platform self-update** — Ed25519 + SHA256 mandatory; distinct from ERP update entitlement.
7. **Stage resource isolation** — CPU/RAM/PID limits with Production priority.
8. **Support expiry** — does not stop Production or backup/restore.
