# Historical Evidence Policy

Per mission §71:

1. **Do not rewrite** historical certification reports or phase evidence.
2. **Add supersession** notes where old architecture is referenced in indexes (e.g. `HARDENING_BASELINE.md`, `DECISION_LOG` D132).
3. **Classify** `docs/evidence/*` as historical unless explicitly re-certified.
4. **Operator docs** (`docs/user/`, public-docs) reflect current contract + implementation matrix.

## Examples

| Historical | Superseded by |
|------------|---------------|
| D129 D2 workers=0-only | D132 + SOVIEZ_SH_PRODUCT_CONTRACT §9 |
| S6 artifact `0.24.5.1` pins in evidence | PROJECT_STATE `0.24.6.3` for operator pins |
| `documentation-canonicalization/` (2026-08-12) | `soviez-sh-documentation-canonicalization/` (2026-08-22) |
