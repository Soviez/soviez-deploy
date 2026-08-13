# Data egress audit
Connected entitlement/release/registry calls may send only: device proof, account id, license id, production environment id, digests, capability name, idempotency/nonce/timestamp.
Never: customer data, DB dumps, filestore, passwords, private keys, unrestricted logs.
No periodic entitlement polling.
