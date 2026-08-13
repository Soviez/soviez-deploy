# SIGNING_AND_TRUST_CHAIN

Distinct purpose keys: offline bundle, authorization, release, addon; root/intermediate. Ed25519 for manifests/authorization; OCI digests for images; pinned public trust roots on offline server; private keys never in bundle; canonical JSON serialization.
