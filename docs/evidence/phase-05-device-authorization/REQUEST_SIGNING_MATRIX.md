# Request signing matrix

| Case | Expected |
|------|----------|
| Valid signature | Accept |
| Wrong key | Reject |
| Changed body | Reject |
| Changed path | Reject |
| Changed method | Reject |
| Timestamp skew | Reject |
| Reused nonce | Reject |
| Revoked device | Reject |
| Expired credential | Reject |
| Credential without sig | Reject |
