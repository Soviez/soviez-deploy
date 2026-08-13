# INSTANCE_CARD_AND_DETAIL_UX.md

## License / Instance cards (Overview)

`LicenseCard` (real component) now shows:

- Friendly name + pencil edit (PATCH `/api/licenses/[id]/alias`)
- Abbreviated License ID + product/version summary from `/api/licenses/[id]/instance-summary`
- Three status groups: Soviez.sh · Support & Updates · Stages
- Available Instance Migration Tokens
- Open Instance → `/dashboard/instances/[id]`
- Existing Migrate Instance + activation key copy actions retained

## Instance detail tabs

Real page tabs:

1. Overview  
2. Activation (Manual + Automatic)  
3. Migration  
4. Server Connection  
5. Support & Updates  
6. Stage License  
7. Stages  
8. Operations  

## Smoke (2026-07-30)

- Card summary API for seeded Main Production returned Disconnected / Inactive / Inactive + `migrationTokens: 1`
- Alias PATCH succeeded (`Main Production`)
- Instance HTML route HTTP 200 under real session
