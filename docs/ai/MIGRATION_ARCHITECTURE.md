# Migration architecture

## Existing
License hardware migration via deactivate + HMAC + token burn + rebind (SaaS+ERP). No server↔server `--migrate-in`.

## Planned
Sovereign assistant: destination bootstrap; signed landing; DNS Try Again/Abort; stream; token integration; source retain default; resumable workers.
