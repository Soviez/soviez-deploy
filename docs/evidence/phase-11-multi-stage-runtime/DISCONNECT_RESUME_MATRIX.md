# DISCONNECT_RESUME_MATRIX

| Capability | Status |
|------------|--------|
| Persisted op `state.json` | ✅ |
| `--stage-reattach` | ✅ |
| `soviez_stage_sm_should_run` strict `<` resume | ✅ |
| Durable worker (`SOVIEZ_STAGE_DURABLE_WORKER`) | ✅ |
| Test pause hooks `SOVIEZ_STAGE_PAUSE_AT` | ✅ |
| Interrupt after authorization | ✅ exercised |
| Interrupt during DB dump | ✅ |
| Interrupt during filestore | ✅ |
| Interrupt during DB restore | ✅ |
| Interrupt before neutralization | ✅ |
| Interrupt during SSL wait | ✅ |
| Interrupt after origin cert / before remote complete | ✅ |
| Worker kill + restart / reattach | ✅ |
| systemd unit rendered; test-mode worker process | ✅ |
| Disposable container reboot recovery | ✅ `REBOOT_RECOVERY_E2E.md` |

Suite: `tests/integration/test_stage_disconnect_resume_e2e.sh`
