# CAPABILITY_UI_COVERAGE.md

License-centered customer UX in the **real** SaaS app (not fixture):

| Capability | UI entry | Backend |
|------------|----------|---------|
| License/Instance card | Dashboard | licenses + instance-summary |
| Manual activation | Activation tab | license_key |
| Automatic activation | Activation / Server Connection | cli_devices |
| Migration tokens | Card + Migration tab | ip_migration_credits / migrate |
| Annual Support | Support & Updates | quote + prepaid checkout + coverage periods |
| Stage License | Stage License tab | quote + subscription checkout + entitlements |
| Legacy monthly | Support banner | historical coverage; monthly new-sale denied |
| Admin commercial | `/admin` | settings / grants / transactions |
