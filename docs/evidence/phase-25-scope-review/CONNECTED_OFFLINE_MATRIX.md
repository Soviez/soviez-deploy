# Connected / offline matrix

| Capability | Connected | Offline/air-gap | Notes |
|------------|-----------|-----------------|-------|
| Clean install | Mandatory | Mandatory (offline package path) | Pairwise OS |
| Activation | Auto + manual | Offline activation | E2E-02 |
| Update | Mandatory | Offline bundle apply | E2E-03/04 |
| Registry pull | Mandatory short-lived | N/A during air-gap apply | Creds cleaned |
| Backup/restore | Optional network dest | Local mandatory | Remotes if certified |
| Stage | Typical connected entitlement | Local runtime independence | |
| Migration | Connected streaming | Offline pairing packages where owned | |
| Diagnostics/status | Works if SaaS down | Must work | Sovereignty |
| Reconciliation | Later online | Must not disable ERP if pending | P23 |
