# RUN_ALL_RESULT

## Final authoritative run (after S6 certification + flake fix)

```bash
bash tests/run_all.sh
```

| Metric | Value |
|--------|-------|
| Result | **PASS** |
| Total OK | **375** |
| Total FAIL | **0** |
| Exact exit code | **0** |
| Duration | **2745 s** (~45.8 min) |

Includes S1–S5, S5 corrective, Phase 24, and S6 focused suite (`SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1`).

## Authoritative nested S6 (standalone)

```bash
SOVIEZ_S6_MATRIX_MODE=execute bash tests/security/run_security_gate_s6.sh
```

| Metric | Value |
|--------|-------|
| Result | **PASS** |
| Exit | **0** |
| Duration | **682 s** |

## Artifact certified

- Version: `0.24.5.1-security-s5-corr1`
- SHA256: `78092b384b28dc45a93801c5d0acad7d90e4ca3e41cd0b235419c2eeeb6531ca`
- Not published
