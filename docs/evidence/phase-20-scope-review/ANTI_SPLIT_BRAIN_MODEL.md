# ANTI_SPLIT_BRAIN_MODEL.md

## Shared invariant

Only one side may be **traffic-serving Production** at a time.

| Epoch | traffic_owner | licensed_future_owner |
|-------|---------------|------------------------|
| Before Phase 21 | source | destination |
| After Phase 21 | destination | — |
| Source after cutover | rollback/archive policy (22) | — |

## Source during grace

Continue traffic; block new permanent bind, new migration, Stage create, clone, update switch, restore-to-new-Production, device reauth, License export, commercial duplication.

## Destination before Phase 21

No Production-domain route, no public login, no inbound business traffic, no outbound mail/payments/webhooks, no customer DNS, no third-party callbacks, no source-like public endpoint.

## Detection

Fail closed on: both public; destination public early; duplicate slot; duplicate unrestricted License use; split-brain codes → Phase 21 BLOCKED.
