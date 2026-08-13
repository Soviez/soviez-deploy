# API_MATRIX — Phase 10.5

| Endpoint | Auth | Purpose |
|----------|------|---------|
| POST `/api/installer/stage/operations/authorize` | Device PoP | Issue ticket |
| POST `/api/installer/stage/operations/consume` | Device PoP | One-use consume |
| POST `/api/installer/stage/operations/complete` | Device PoP | Neutralization + origin |
| POST `/api/installer/stage/operations/status` | Device PoP | Status |
| POST `/api/installer/stage/operations/revoke` | Device PoP | Revoke unused |
| POST `/api/installer/stage/operations/offline/package` | Device PoP | Offline package |

Routes under `soviez-saas/src/app/api/installer/stage/operations/`.

**Tests:** _(parent fills)_
