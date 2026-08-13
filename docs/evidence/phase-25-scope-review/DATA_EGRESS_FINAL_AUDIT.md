# Data-egress final audit

Classify every outbound category:

| Category | Class |
|----------|-------|
| Device auth / entitlement check (user-initiated) | ALLOWED_USER_INITIATED |
| Registry pull ticket + layer fetch during update/install | ALLOWED_OPERATION_REQUIRED |
| ACME/DNS as designed | ALLOWED_OPERATION_REQUIRED |
| Business DB/filestore/backup payloads to Soviez | FORBIDDEN |
| Customer secrets upload | FORBIDDEN |
| Local ops registry / status | LOCAL_ONLY |
| Offline apply | LOCAL_ONLY |

Confirm no business data sent externally.
