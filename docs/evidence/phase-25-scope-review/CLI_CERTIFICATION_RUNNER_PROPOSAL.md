# CLI / certification-runner proposal

Prefer certification scripts over new customer runtime commands:

```text
tests/phase25_final_certification.sh
tests/phase25_release_checklist.sh
tests/phase25_docs_sync.sh
```

Authoritative orchestrator name: `phase25_final_certification`.

Existing `--security-phase25-readiness` remains informational preflight only — not a substitute for the matrix.
