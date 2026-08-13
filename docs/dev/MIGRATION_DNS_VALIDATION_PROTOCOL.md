# Migration DNS Validation Protocol

## Path

1. Publish TXT + A/AAAA or CNAME per domain plan / instructions
2. Query **authoritative** NS for the zone
3. Query **≥2 public/recursive** resolvers
4. Require exact value agreement with authoritative
5. Optional DNSSEC validation when zone is signed; CAA checked before ACME

## Lab / e2e

- CoreDNS authoritative + two recursive forwarders on a Docker network
- `dig` executed **via docker network** (Colima host UDP publish unreliable)
- Mock DNS provider writes fixture zone files for unit/integration

## Try Again

`--migration-dns-try-again` re-observes the **same** challenge id (idempotent when already verified). Propagation WARNING/BLOCKED windows follow Phase 18 OD defaults (15m / 60m guidance).
