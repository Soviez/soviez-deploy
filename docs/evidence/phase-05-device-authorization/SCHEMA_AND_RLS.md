# Schema and RLS — Phase 5

Migration: `081_device_authorization_foundation.sql`

## Tables
- `cli_devices` — status CHECK active|revoked|replaced|compromised|disabled
- `device_auth_sessions` — state CHECK pending|approved|denied|expired|consumed; code hashes
- `device_credentials` — status CHECK active|revoked|expired|replaced; credential_hash unique
- `device_request_nonces` — unique (device_id, nonce); expires_at indexed

## RLS
- anon: deny all device tables
- authenticated: SELECT own `cli_devices` only; no writes
- sessions/credentials/nonces: deny anon+authenticated (service-role only)
- `cleanup_device_auth_ephemera`: SECURITY DEFINER, service_role, fixed search_path

## Verified
Isolated Docker certification over migrations 078–081.
