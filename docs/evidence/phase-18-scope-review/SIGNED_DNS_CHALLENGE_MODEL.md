# SIGNED_DNS_CHALLENGE_MODEL.md

## Purpose

Prove **exact** owner control of the migration FQDN and bind it to exact migration pair + destination identity — **not** account-wide, **not** wildcard, **not** TOFU.

## Binding fields (canonical)

`migration_pair_id | source_environment_id | source_domain | migration_fqdn | destination_bootstrap_id | destination_host_fingerprint | license_id | operation_id | nonce | expires_at`

Signed with Device/app key (same trust family as Phase 17). Digest stored; challenge one-time consumable.

## Record model (recommended default)

1. **TXT** ownership: name `_soviez-mig.<migration-fqdn>` or `_acme-challenge` only if ACME DNS-01 shares path — prefer dedicated `_soviez-mig.` to avoid clobbering LE. Value = `v1.<challenge_id>.<sig_or_token_hash>` (no system-access secret).  
2. **A/AAAA or CNAME** reachability: migration FQDN → destination public address(es) or approved CNAME target **exactly** matching plan.

TTL recommendation: **300s**. Challenge validity: **30 minutes** (OD-05).

## Validation

- Authoritative NS query for zone  
- ≥2 public resolvers must agree with authoritative (OD-09)  
- Exact value match; no partial wildcard  
- Replay: consumed/expired/nonce mismatch → deny  
- DNSSEC: validate when zone is signed; soft-fail policy when unsigned (OD-10)  
- CAA: checked before ACME (see TLS model)  
- IPv4 mandatory; IPv6 optional unless configured (OD-11)  

## Cleanup

On Abort: challenge revoked locally; **do not** auto-delete owner DNS (OD-14) unless Phase 18 provider adapter created the exact record.
