# REAL_AIR_GAPPED_APPLY

Suite: `tests/integration/test_phase23_real_airgapped_apply.sh`

After import: plan + apply with black-hole proxies (`http://127.0.0.1:1`).
Asserts:
- `NETWORK REQUIRED DURING APPLY — NO`
- `RESULT RECEIPT — SIGNED`
- `SOVIEZ_OFFLINE_APPLY_NETWORK_DENIED=1`
- `network_required_during_apply=false`
- `unexpected_network_attempts=0`
