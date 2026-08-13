# Domain/SSL contract

## Existing
FQDN mandatory for `--new` and Stage; interactive DNS loop with optional `force`; self-signed then Certbot.

## Planned
Signed challenge endpoint; Stage acceptance requires valid HTTPS/cert/environment signature; eliminate Stage force-accept; finite Try Again/Abort.
