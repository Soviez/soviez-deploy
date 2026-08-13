# SECRET_HANDLING_AUDIT

| Secret | Handling |
|--------|----------|
| Stage Operation private keys | Never on client; helper public keys only |
| Ticket token | Op auth dir mode 600 |
| Stage secrets dir | `700` |
| Offline request | 600; metadata only |
| Evidence pack | No keys/passwords/service-role |

