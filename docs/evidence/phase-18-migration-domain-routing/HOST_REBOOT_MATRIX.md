# HOST_REBOOT_MATRIX

`tests/integration/test_phase18_reboot_matrix.sh`

| Path | Result |
|------|--------|
| Host-disk persistence of domain plan + DNS challenge + ops state across process re-source | **PASS** (2026-08-02, `SOVIEZ_P18_SKIP_COLIMA_REBOOT=1`) |
| Optional Colima stop/start | **Not exercised** — Colima not running during documentation certification |

Owner DNS marker survives reboot simulation.
