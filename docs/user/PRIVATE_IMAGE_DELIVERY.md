# Private image delivery

Flow:

1. Soviez.sh starts an authorized operation
2. SaaS issues a short-lived Registry Ticket (Ed25519, pull-only, repo+digest bound, TTL 15m)
3. Installer uses a temporary `DOCKER_CONFIG` to authenticate to `registry.soviez.com`
4. Registry Gateway verifies ticket offline and proxies only the authorized digest graph
5. Installer verifies exact digest, then deletes temporary docker credentials

Upstream Hub credentials remain only on Soviez infrastructure.
