# NEXT_GATE

Start `tests/run_all.sh` in the next mission only. Preconditions satisfied:

- `CLEAN_FROZEN_CERTIFICATION_TREE = PASS`
- `cert/0.24.6.4-platform-cli` pushed; artifact SHA `c76c59e9…937f`
- Moving-tree guard wired in `tests/run_all.sh`
- ERP fixtures resolve via `tests/helpers/erp_release_fixture.sh` → `cert-0.24.6.4`
