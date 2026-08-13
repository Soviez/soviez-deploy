# LIVE_SIMULATION_PREREQUISITES

## Infrastructure
| Need | Spec |
|------|------|
| VPS A | Ubuntu 22.04/24.04 — Production destination |
| VPS B | Same — Stage / update / rollback exercises (or same host if product supports; prefer 2) |
| VPS C | Migration **source** (disposable) |
| VPS D | Optional second destination / archive target |
| DNS | Dedicated test zone; Production FQDN + Stage FQDN (or wildcard `*.stage.example`) |
| TLS | Let’s Encrypt staging or real test certs |
| SaaS | **staging/sandbox** project (not customer Production) |
| License/Device | Synthetic test License + Device + slot |
| Registry | Test pull credentials / tickets against registry.soviez.com or mock gateway |
| Backup target | S3-compatible **or** SFTP disposable bucket/server |
| Offline bundle | Generated test bundle entitlement |
| SMTP sink | Mailhog/Mailpit |
| Webhook sink | requestbin/webhook.site or local |
| Cloudflare | Optional mode only |

## Isolation
`ISOLATED_REAL_INFRASTRUCTURE` — real VPS/DNS/network, **synthetic data only**.  
**No real customer data. No customer Production.**

## SaaS environment
Existing Production SaaS must **not** be required. If no staging exists → **BLOCKS_LIVE_SIMULATION** unless owner explicitly authorizes isolated test records on Production SaaS (discouraged).
