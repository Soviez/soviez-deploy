# EVIDENCE_PUBLICATION_POLICY

| Class | Policy | Examples |
|-------|--------|----------|
| PUBLISH_REQUIRED | Gate summaries + final certificates | `phase-25-final-certification/FINAL_*`, post-cert `FINAL_REPORT.md`, security gate PASS summaries |
| PUBLISH_SUMMARY_ONLY | Prefer summaries over raw logs | Large phase trees: keep FINAL/DECISION; omit bulky intermediates if redundant |
| KEEP_LOCAL | Machine-specific / disposable | `/tmp` logs, `.tmp` runtime proofs |
| SENSITIVE | Never publish | Keys, dumps, customer DB names, unrestricted incident logs |
| TOO_LARGE | Exclude binaries | DB dumps, filestore bins under `.tmp` |
| HISTORICAL_REFERENCE | May remain if already non-sensitive markdown | Older phase evidence markdown (~1806 files) |

**Recommendation:** Publish **all non-sensitive markdown evidence** under `docs/evidence/` for auditability (~8.8MB — practical), but **never** `.tmp` runtime trees. Owner may later slim to summaries-only without invalidating certification if summaries + hashes retained.

This audit's pack: `docs/evidence/pre-publish-readiness/**` → PUBLISH_REQUIRED.
