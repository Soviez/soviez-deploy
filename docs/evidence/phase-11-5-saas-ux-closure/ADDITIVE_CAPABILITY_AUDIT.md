# ADDITIVE_CAPABILITY_AUDIT.md

| Capability | Old behavior | New optional behavior | Old remains | Data model | Routes | APIs | Historical readable |
|------------|--------------|----------------------|-------------|------------|--------|------|---------------------|
| Manual Activation | Key + instructions | unchanged | YES | YES | YES | YES | YES |
| Automatic Activation / Device Auth | n/a / optional | Device authorize/revoke/reauth | YES (manual) | additive tables 081 | dashboard Devices/Servers | installer-auth APIs | YES |
| Servers | IP / deploy context | Device-linked servers | YES | additive | dashboard/servers | YES | YES |
| Annual Support | Monthly historical | Prepaid multi-year Annual | YES (legacy monthly visible; new monthly blocked) | 084 + coverage periods | Support tab | `/api/support/annual/*` | YES |
| Stage License | n/a | Monthly Stage entitlement | n/a additive | 085 | Stage License tab | `/api/stage-license/*` | YES |
| Stage Operations | local | Tickets / gated ops | local ops remain | 086 | Operations | stage-operation APIs | YES |
| Offline authorization | n/a | offline packages | additive | device/registry | installer | YES | YES |
| Private Registry | n/a | pull tickets | additive | 083 | Releases admin | registry APIs | YES |
| License Slots | legacy RPCs | reservation foundation | dual-write / shadow | 082 | admin slots | YES | YES |
| Migration Tokens | self-service credits | unchanged primary | YES | YES | YES | YES | YES |

**FAIL condition:** new feature silently replaced required old flow — **not observed**.
