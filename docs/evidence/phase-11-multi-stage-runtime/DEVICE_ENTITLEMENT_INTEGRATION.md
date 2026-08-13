# DEVICE_ENTITLEMENT_INTEGRATION

| Step | Status |
|------|--------|
| Silent device if credential present | ✅ coded |
| Consent branch if missing | ✅ `waiting_for_connection_consent` |
| Stage entitlement check | ✅ gated create |
| Expired entitlement deny create | ✅ integration exit 20 |
| Fixture skip device | `SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE=1` for harness |

