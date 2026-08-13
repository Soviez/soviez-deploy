# REGISTRY_EXPORT_MODEL

Connected export worker: verify entitlement+auth → short-lived scoped Registry access → pull exact digest → export OCI → verify digest → remove credentials → package+sign.

Exact repo/digest only; no permanent Docker config; no creds in bundle; private artifact storage; signed issuance record.
