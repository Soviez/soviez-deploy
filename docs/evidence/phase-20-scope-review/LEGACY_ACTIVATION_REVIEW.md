# LEGACY_ACTIVATION_REVIEW.md

| Item | Assessment |
|------|------------|
| `SOVIEZ_MIGRATION_SECRET` | LG HMAC secret — **not** Migration Token |
| Legacy deploy activation | First bind patterns; not Phase 20 migrate |
| Dashboard migrate wizard (`begin`/`migrate`) | Soft-reserve wallet + OTP + deactivation receipt + IP/fingerprint rebind — **closest live burn**, unsafe to reuse unmodified for installer Phase 20 |
| `consume_ip_migration_token` / `secure_license_ip_migration` | Obsolete vs 070 session |
| Slot `--new` activation | Creates License/slot — opposite of migrate (must not mint second License) |

Phase 20 should learn receipt/HMAC and idempotency patterns; replace wallet-as-SoR with ledger commit tied to Phase 19 pair.
