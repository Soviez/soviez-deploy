# REAL_PRIVATE_IMAGE_PULL — End-to-End Pull Proof

## Verdict

**PASS**

## Mode

`gateway_http_oci_disposable_upstream`

Proof script: `soviez-sh/services/registry-gateway/scripts/real-oci-pull-proof.sh`

## Method

1. Build gateway (`npm run build`).
2. Start disposable mock upstream (OCI manifest + layers).
3. Start gateway bound to mock with server-side upstream credentials (`hub-secret-must-never-egress`).
4. Issue valid Ed25519 pull ticket (TTL 900s) for mock repository + digest.
5. Deny invalid ticket (401).
6. Pull manifest (200, schemaVersion 2).
7. Exchange Docker Basic auth at `/auth/token` — assert no upstream user/token in body.
8. Pull all layer blobs (200, non-zero size).
9. Create and delete temporary docker config dir (credential cleanup proof).

## Recorded output

```json
{
  "REAL_PRIVATE_IMAGE_PULL": "PASS",
  "mode": "gateway_http_oci_disposable_upstream",
  "repository": "<mock repository>",
  "digest": "<mock manifest digest>",
  "upstream_secret_egress": "NONE",
  "credential_cleanup": "PASS",
  "invalid_ticket": "DENIED"
}
```

## What this proves

| Property | Status |
|----------|--------|
| Ticket-gated manifest pull | PASS |
| Ticket-gated blob streaming | PASS |
| Invalid ticket rejected | PASS |
| No upstream credential egress | PASS |
| Temp credential dir cleanup | PASS |

## What this does not prove (yet)

| Gap | Status |
|-----|--------|
| Live pull against Docker Hub production image | **PENDING** (requires staged gateway + real Hub PAT) |
| Pull through `registry.soviez.com` TLS edge | **PENDING** (VPS/nginx not provisioned) |
| Installer `soviez.sh` full stage pull on live SaaS | **PENDING** (`LIVE_SIMULATION_READINESS.md`) |

## Related unit tests

Gateway test suite includes complementary cases: valid manifest+blobs, range requests, token exchange — **20/20 PASS**.
