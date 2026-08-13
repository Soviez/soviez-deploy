# Registry troubleshooting

| Symptom | Check |
|---------|-------|
| Login/pull denied | Ticket expired? Wrong gateway URL? Device/License entitlement? |
| Digest mismatch | Confirm SaaS release digest; do not pull `:latest` |
| Gateway `/ready` 503 | Public keys JSON not configured |
| Offline update fails | Offline path does not use Gateway — check bundle signatures |
| ERP down after Gateway outage | Unexpected — runtime must not depend on Gateway after pull |
