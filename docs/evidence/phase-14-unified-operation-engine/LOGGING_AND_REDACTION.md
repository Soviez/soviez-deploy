# Logging and Redaction

**Phase:** 14  
**Verdict:** PASS  

## 1. Privacy Contracts

All command-specific outputs written to `$SOVIEZ_OPS_ROOT/operations/<id>/operation.log` are sanitized to enforce the Soviez Sovereignty standards.

- **Centralized Redaction:** Outputs are filtered using `soviez_redact_text` under `src/core/redact.sh`.
- **Redaction Rules:** 
  - Erases credentials matching strings such as `postgres://user:password@host/db`.
  - Scrubs private key boundaries (`BEGIN PRIVATE KEY`).
  - Redacts hardware keys, license codes, or authentication tokens.
- **Local Storage ONLY:** Logs reside on the client-controlled host only. Automatic uploading of logs, stack traces, or terminal outputs to Soviez SaaS is strictly forbidden.
