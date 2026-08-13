# AUTOMATIC_ROLLBACK_TRIGGERS.md

## Design stance

Automatic rollback is **high risk** (false positives during propagation). Default: **advisory triggers** with operator confirm; optional **enforced** subset via owner policy (OD-26).

## Trigger catalog

| ID | Condition | Severity | Default action |
|----|-----------|----------|----------------|
| AR-01 | Mandatory health check failure (3 consecutive) | Critical | **Recommend rollback** |
| AR-02 | ERP `/web/login` 5xx > 50% over 2 min | Critical | **Recommend rollback** |
| AR-03 | TLS certificate invalid mid-window | Critical | **Enforced rollback** (OD-26) |
| AR-04 | Split-brain detector: both sides public ERP | Critical | **Enforced rollback** |
| AR-05 | Database connectivity lost on destination | Critical | **Recommend rollback** |
| AR-06 | License Guard hard deny on destination | High | **BLOCK** commit retroactive; if post-commit → recommend |
| AR-07 | DNS reverted to source majority unexpectedly | High | Advisory — investigate |
| AR-08 | Payment capture detected during window with health FAIL | Critical | **Needs Action** — no auto DNS rollback |
| AR-09 | Source writes detected during cutover_maintenance | Critical | **Enforced freeze** + advisory |
| AR-10 | Propagation timeout (>15m no majority) | Medium | Pause commit; advisory |

## Enforcement levels

| Level | Behavior |
|-------|----------|
| **Advisory** | Log + operator notification; no automatic DNS change |
| **Enforced** | Initiate rollback operation engine sequence (requires OD-26 enable) |
| **Needs Action** | Stop automation; human playbook |

## Pre-commit vs post-commit

- **Pre-commit** (before traffic_owner flip): abort cutover; no DNS rollback needed.
- **Post-commit**: invoke `ROLLBACK_MODEL.md` sequence.

## False positive mitigation

- Ignore blips < 30s unless repeated.
- Require correlation: health + split-brain, not single resolver flake.
- Propagation grace: suppress AR-01 for first 2 minutes post-DNS attestation (OD-27).

## Reporting

All triggers append to cutover operation audit JSON with timestamp, signal, action taken.

## OWNER DECISION REQUIRED

**OD-26:** Enable enforced auto-rollback for AR-03 and AR-04?

**Recommendation:** **Yes** for AR-04; **Advisory** for AR-03 unless cert completely invalid.

**OD-27:** Propagation grace suppress duration for health triggers?

**Recommendation:** **120 seconds** after DNS attestation.
