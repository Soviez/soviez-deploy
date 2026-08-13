# Device flow matrix

| Step | Result |
|------|--------|
| Start valid key | Session pending; hashed codes; no account |
| Start malformed key | Rejected |
| Oversized label | Rejected |
| Browser unauthenticated | Redirect login |
| Approve | State approved + account_id |
| Deny | State denied |
| Expire cleanup | pending→expired |
| Token pending | authorization_pending |
| Token slow_down | interval enforced |
| Token after approve + PoP | credential once; consumed |
| Token reuse | invalid_grant |
| Revoke | device+creds revoked |
