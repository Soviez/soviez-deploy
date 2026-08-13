# AUTHORITATIVE_S6_RUN

## Focused (recorded PASS)
Command: `SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s6.sh`  
Result: **PASS** (exit 0)  
Artifact: `0.24.5.1-security-s5-corr1` SHA256 `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`  
When: 2026-08-12 (focused suite ~67s)

## Nested full S6
Command: `bash tests/security/run_security_gate_s6.sh` (matrix execute; nested S1–S5/corr/P24)  
Result: **PENDING** at evidence write

## run_all
`tests/run_all.sh` → **PENDING** at evidence write
