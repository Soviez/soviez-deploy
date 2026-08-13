# License-centered UX map — Phase 11.5 correction

## Outside (Overview)

Each License / Instance is a compact card:

- Alias, abbreviated id, product/version
- Status badges (activation, Annual Support, Stage License)
- Server label summary + Stage count
- Affordance: Open instance details

## Inside (same card context — tabs)

| Tab | Content |
|-----|---------|
| Overview | Activation, entitlement badges, warnings |
| Server / Connection | Device status, fingerprint, reauthorize, Revoke Server Access vs Unlink |
| Annual Support | Coverage, legacy monthly messaging, pricing policy, renew/extend |
| Stage License | Status, create allowed/denied, existing unaffected |
| Stages | Metadata list + local runtime note |
| Operations | History, DenialCard, offline request export |
| Security | Revoke vs unlink semantics; safe export rules |

## Global lists

No separate Servers/Stages/Operations product IA. Cross-license admin views remain under `/admin/*`.
