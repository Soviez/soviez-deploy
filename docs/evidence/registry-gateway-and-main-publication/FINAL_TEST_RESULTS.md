# FINAL_TEST_RESULTS — Registry Gateway + Main Publication

## Summary

| Suite | Result | Notes |
|-------|--------|-------|
| Gateway unit tests | **20/20 PASS** | `npm test` in `services/registry-gateway` |
| REAL_PRIVATE_IMAGE_PULL | **PASS** | `gateway_http_oci_disposable_upstream` |
| soviez-sh `run_all.sh` | **PENDING** | In progress on `0.24.5.3-registry-gateway` |
| SaaS registry tests | In tree | Post-push CI **PENDING** |
| Live staging E2E | **PENDING** | No staged stack |

## Gateway unit test inventory (all PASS)

| # | Test case |
|---|-----------|
| 1 | live, ready, and health alias return ok |
| 2 | REG basic auth token exchange (docker login path) |
| 3 | REG push scope denied at token endpoint |
| 4 | REG wrong audience/service denied |
| 5 | REG wrong license binding denied |
| 6 | REG wrong device binding denied |
| 7 | REG rate limit eventually trips on /v2/ |
| 8 | unauthorized manifest denied |
| 9 | GET /v2/ without auth returns 401 with WWW-Authenticate |
| 10 | valid ticket allows manifest and blobs |
| 11 | auth token exchange returns bearer metadata |
| 12 | wrong repo denied |
| 13 | wrong digest denied |
| 14 | unauthorized blob digest denied |
| 15 | catalog denied |
| 16 | tags list denied |
| 17 | push denied |
| 18 | expired ticket denied |
| 19 | range request works on layer blob |
| 20 | secrets absent from logs |

## Security-focused tests (mapped)

| Evidence doc | Covered by |
|--------------|------------|
| TOKEN_EXPIRY_TEST | #18 |
| SCOPE_ENFORCEMENT | #3, #12–17 |
| NO_UPSTREAM_CREDENTIAL_EGRESS | #2, real pull proof |
| LOG_REDACTION | #20 |

## Baseline comparison

| Artifact | run_all |
|----------|---------|
| `0.24.5.2-postcert-corr1` | 218 OK / 0 FAIL |
| `0.24.5.3-registry-gateway` | **PENDING** |

## Commercial release

**NOT AUTHORIZED** — test pass does not imply production rollout authorization.
