# DEMO_SEED_MATRIX.md

Seed script: `soviez-saas/scripts/seed-phase115-full-demo.ts`  
Target: isolated demo `bzkokygmagcseasuiiqs` only.

## Accounts

| Role | Email | Password |
|------|-------|----------|
| Customer | customer.demo@soviez.local | Demo-Customer-11.5! |
| Admin | admin@admin.com | 010203@## |

## Instances

| Alias | License ID | Soviez.sh | Support | Stages | Tokens |
|-------|------------|-----------|---------|--------|--------|
| Main Production | 1a8dd6a7-e6ec-4742-ac48-6d81ba9b9f06 | Connected (HQ Production Device) | Active Annual | Active | 2 |
| Warehouse | 64a85785-ae73-4bfe-81f5-def8e8353af1 | Needs Action (disabled Device) | Expired Annual | Expired entitlement | 0 |
| Legacy Site | 978c8ef6-ec40-49c8-b526-422618d6e8a9 | Disconnected | Legacy Monthly | Inactive | 1 |

## Commercial seeds

- Multi-year discount rules 1–5y: 0/10/15/20/25%
- EG Annual Support country price: 3,000,000 piastres (= 30,000 EGP = 20% of 150,000 EGP)
- SA Annual Support country price: 500,000 halalas (= 5,000 SAR = 20% of 25,000 SAR)
- Stage License EG monthly price seeded
- Devices tagged with `metadata.license_id` + `seed=phase115`
- Stage operation authorization rows for demo Stages/ops

## Artificial only

No production customer IDs, secrets, private keys, or live payment instruments.
