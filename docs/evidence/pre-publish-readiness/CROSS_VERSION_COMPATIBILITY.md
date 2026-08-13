# CROSS_VERSION_COMPATIBILITY

| Pairing | Safe? | Notes |
|---------|------:|-------|
| new soviez-sh + current main ERP wizard | **NO** | Post-cert Stage proxy_mode / WS / workers fixes are in wizard working tree, not necessarily on remote main |
| current main soviez-sh + new ERP wizard | Partially | Wizard alone improves Stage; modular nginx/topology still needs new soviez-sh for full parity |
| new ERP wizard ≠ new deploy wizard | **NO** | Must publish atomically identical |
| new soviez-sh + old SaaS | **NO** for advanced lifecycle | See SAAS_SCHEMA_COMPATIBILITY |
| Coordinated publish (saas → wizards+sh) | **YES** | Required |

Classification: **COORDINATED / ATOMIC** publication across saas + sh + both wizards.
