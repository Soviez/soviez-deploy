# STALE_FIXTURE_MIGRATION

Migrated active tests from hardcoded `soviez/erp:p15-*` to `tests/helpers/erp_release_fixture.sh` catalog resolver (`cert-0.24.6.4`).

Touched:
- tests/integration/test_update_final_certification.sh
- tests/integration/test_restore_test_real.sh
- tests/unit/test_update_image_cleanup_unit.sh
- tests/security/platform/test_odoo_functional_least_privilege.sh
- tests/helpers/phase19_cert.sh (SOVIEZ_MIG_ERP_IMAGE default)
- tests/helpers/phase23_cert.sh (delegates fixture ensure)
