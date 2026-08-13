# Troubleshooting — Soviez Registry Gateway

## Healthcheck fails

Symptoms: `./healthcheck.sh` cannot reach `/live` or `/ready`.

1. `docker compose -f /opt/soviez-registry-gateway/compose.yml ps`
2. `docker compose … logs --tail=200`
3. Confirm bind: `ss -lntp | grep 8087` (expect `127.0.0.1:8087`)
4. Confirm env file exists and is sourced: `/etc/soviez-registry-gateway/gateway.env`

## 401 on `/v2/`

Expected without a valid Bearer ticket. Check `WWW-Authenticate` realm points at `/auth/token`.

If tickets that should work fail:

- Validate `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON` key id matches `signer_key_id`
- Confirm raw public key encoding (base64url, 32-byte Ed25519)
- Check ticket `exp` / clock skew on the host

## 403 repository or blob scope

Ticket binds a single repository + root digest. Manifest must match; blobs must be in the session digest graph built from that manifest. Wrong repo/digest → denied by design.

## Upstream 502 / unavailable

- Verify Hub user/token on the **gateway host only**
- From the host: outbound HTTPS to `registry-1.docker.io`
- Ensure credentials were not pasted into client-side config (they must not be)

## nginx 502 Bad Gateway

- Backend down or not on `127.0.0.1:8087`
- `CERT_*` placeholders still present → `nginx -t` should fail until replaced
- SELinux/AppArmor rarely relevant on stock Ubuntu; check `journalctl -u nginx`

## Compose build failures

- Node 20 required for local `npm` workflows
- Clear build cache only if needed: `docker compose build --no-cache`
- Confirm `package-lock.json` is present in the package

## systemd unit inactive but containers running

Unit is `Type=oneshot` wrapping Compose. Use `docker compose ps` as source of truth for container health; `systemctl start` re-runs `compose up -d`.
