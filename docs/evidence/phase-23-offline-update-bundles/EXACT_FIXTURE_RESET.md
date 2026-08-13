# EXACT_FIXTURE_RESET

Implemented by `soviez_phase23_exact_fixture_reset` in `tests/helpers/phase23_cert.sh`.

Removes only:
- containers with label `soviez.phase23.disposable=1`
- containers named `soviez-p23-*`
- exited `soviez-stage-pg-*` fixtures

Does **not** remove unrelated running ERP/RC containers, unrelated networks/volumes/images, live services, or prior evidence files.

Proven by `tests/unit/test_phase23_exact_fixture_reset.sh`.
