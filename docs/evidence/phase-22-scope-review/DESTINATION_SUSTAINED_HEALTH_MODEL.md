# Destination Sustained-Health Model

Evidence required over the stabilization period (metadata / aggregates only toward SaaS):

| Domain | Evidence |
|--------|----------|
| HTTP | Availability sustained |
| TLS | Validity / chain |
| Auth | Login success smoke |
| DB | Health + growth consistency |
| Filestore | Health + growth consistency |
| Workers / cron | Healthy |
| Mail / webhooks / payments | Delivery / processing OK; no duplicates |
| Queues | Depth within policy |
| Errors | Error rate / severe traceback count within policy |
| Latency | Within policy |
| Backup | Success + freshness |
| License Guard | Consistent |
| Traffic owner | Remains destination |
| DNS | Stable; source not receiving meaningful public traffic |
| Stage | Destination Stage health where applicable |
| Source | No business write activity; no duplicate integration activity |

**Sovereignty:** no request bodies, customer records, or unrestricted logs to SaaS.
