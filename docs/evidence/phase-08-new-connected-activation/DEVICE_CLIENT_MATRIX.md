# DEVICE_CLIENT_MATRIX — Phase 8

**Client:** `src/auth/device_client.sh`  
**Protocol:** `docs/dev/DEVICE_AUTHORIZATION_PROTOCOL.md`

## Integration in `--new`

| Step | Function | SaaS route | State transition |
|------|----------|------------|------------------|
| Start session | `soviez_device_client_start` | `POST /api/installer-auth/device/start` | → `device_authorization_pending` |
| Authorize (browser) | `soviez_device_client_authorize` | `POST /api/installer-auth/device/token` | → `device_authorized` |
| Load existing cred | `soviez_device_client_load_credential` | — (local) | skip auth if valid |

## PoP on downstream calls

All slot and registry API calls via `src/api/http.sh` include Phase 5 signed headers.

## Test matrix

| Scenario | Test | Result |
|----------|------|--------|
| Auto path device auth | `test_new_automatic_path.sh` | PASS |
| Manual path device auth | `test_new_manual_path.sh` | PASS |
| Resume skips re-auth if cred exists | `test_disconnect_resume.sh` | PASS |
| Signing unit tests | `test_signing.sh` | PASS |

## Mock behavior

`tests/integration/mock_saas_server.py` — auto-approves device auth in test mode; returns mock credential.

## Sovereignty

- Device private key never transmitted
- Revocation blocks future ops only
- Device auth alone grants no commercial entitlement
