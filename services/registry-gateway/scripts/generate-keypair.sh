#!/usr/bin/env bash
# Generate registry pull-ticket keypair — INSTRUCTIONS ONLY (no private key material printed as a committed secret).
# This stub tells operators how to generate keys offline; it does not write secrets into the package tree.
set -euo pipefail

cat <<'EOF'
Soviez Registry Gateway — Ed25519 ticket keypair (operator instructions)

DO NOT commit private keys or paste production secrets into git, tickets, or chat.

1) Generate an Ed25519 keypair offline (openssl example):

   openssl genpkey -algorithm Ed25519 -out registry-ticket-ed25519.pem
   openssl pkey -in registry-ticket-ed25519.pem -pubout -out registry-ticket-ed25519.pub.pem

2) Derive the gateway verification value:
   - Gateway expects SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON as:
     { "rtk_<key_id>": "<raw 32-byte Ed25519 public key, base64url>" }
   - Use the issuer tooling / ticket helper in this package (src/ticket.ts
     generateRegistryTicketKeyPair) in a secure offline environment to produce
     keyId + publicKeyRawB64url. Do not leave private keys on the gateway host
     unless this host is also the issuer (usually it is not).

3) Place ONLY the public map on the gateway host:

   /etc/soviez-registry-gateway/gateway.env
   SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON={"rtk_...":"..."}

4) Keep the private signing key in the issuer/control plane secret store.
   Upstream Docker Hub username/token stay ONLY on the gateway host and are
   never returned to pull clients.

5) Rotate by adding a new key id to the JSON map, deploying tickets signed with
   the new key, then removing the old key id after TTL expiry.

For more: docs/CONFIGURATION.md and docs/SECURITY.md
EOF
