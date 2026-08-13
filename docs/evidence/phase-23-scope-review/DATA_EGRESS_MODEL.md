# DATA_EGRESS_MODEL

Forbidden: business DB/filestore/attachments/records/accounting/unrestricted logs/passwords/private keys.

Permitted connected metadata: account/license/environment IDs, device fingerprint, installer version, digests, addon manifest digests, approved custom hashes, entitlement/authorization/bundle IDs, requested target version, compatibility result, public signatures, timestamps, signed result state, non-sensitive failure codes.

No hidden telemetry. Prefer dedicated artifact storage / Registry export over embedding large payloads in SaaS responses.
