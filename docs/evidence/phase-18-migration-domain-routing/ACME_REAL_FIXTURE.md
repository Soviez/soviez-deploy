# ACME_REAL_FIXTURE

Honest ACME lab:

| Component | Detail |
|-----------|--------|
| CA | `ghcr.io/letsencrypt/pebble:2.7.0` |
| Client | `goacme/lego:v4.22.2` |
| Env | `PEBBLE_VA_ALWAYS_VALID=1`, `PEBBLE_VA_NOSLEEP=1` |

**Real:** ACME order, CSR, certificate issue, chain retrieval.  
**Short-circuited:** Pebble Validation Authority (test mode) — not a claim of production Let's Encrypt HTTP/DNS validation.

Fallback: `SOVIEZ_MIG_TLS_FIXTURE=1` non-self-signed fixture leaf when Pebble unavailable.
