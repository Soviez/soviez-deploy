# DOMAIN_SSL_LIFECYCLE_PROTOCOL.md

## Inventory schema

Path: `$SOVIEZ_SSL_INVENTORY_DIR/<environment_id>.json` (mode 600). Fields: environment_id, environment_type, domain, certificate_mode, acme_provider, certificate_path, private_key_path, chain_path, issuer, serial_abbreviated, not_before, not_after, hostname_verification, chain_verification, current_certificate_digest, previous_certificate_digest, renewal_mode, renewal_lead_days, last_renewal_attempt, last_successful_renewal, next_scheduled_attempt, retry_count, last_failure_code, lifecycle_state, readiness_state, operation_id, challenge_id, wildcard_scope, private_ca_policy, created_at, updated_at. **Never** stores private keys or ACME account secrets.

## State machine

See `src/ssl/lifecycle_sm.sh`. Key states: healthy → renewal_window → … → certificate_promoting → completed/healthy; failures → retry_scheduled / needs_action / certificate_expired; rollback_running preserves prior material.

## CLI

```bash
sudo soviez.sh --ssl-status [environment-id]
sudo soviez.sh --ssl-renew <environment-id>
sudo soviez.sh --ssl-repair <environment-id>
sudo soviez.sh --ssl-reattach <operation-id>
sudo soviez.sh --ssl-policy <environment-id> [automatic|notify_only|manual]
sudo soviez.sh --ssl-try-again <environment-id>
sudo soviez.sh --ssl-abort <environment-id>
```

Exit: `SOVIEZ_ERR_SSL` (7) with `SSL_DENIAL code=...` on stderr.

## Failure codes

Defined in `src/ssl/codes.sh` (NO_MANAGED_ENVIRONMENT … DESTRUCTIVE_CONFIRMATION_REQUIRED).

## Paths

- Certs: `$SOVIEZ_SSL_CERTS_DIR/<env_id>/`
- Staging: `$SOVIEZ_SSL_STAGING_DIR/<op_id>/`
- Challenges: `$SOVIEZ_SSL_CHALLENGE_DIR/<challenge_id>.json`
- Nginx owned: `$SOVIEZ_SSL_NGINX_OWNED_DIR/<env_id>__<domain>.conf`

## Challenge contract

Binding digest over `env|domain|host|op|mode|provider|type|nonce|wildcard_scope`. Replay/expiry/tamper/wrong-binding rejected. No automatic DNS-provider mutation.

## Provider interface

`soviez_ssl_provider_issue <provider> <domain> <cert> <key> <chain>` — `fixture`/`local_ca`/`test` or `letsencrypt` (test mode forces fixture).

## Promotion / rollback

Validate → backup current → stage Nginx → `nginx -t` → promote files → reload → HTTPS check → finalize; on failure restore previous cert/config.

## Permissions

Private keys 600; inventory/challenge 600; dirs 700.
