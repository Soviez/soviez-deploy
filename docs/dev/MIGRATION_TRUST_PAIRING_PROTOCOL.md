# Migration Trust Pairing Protocol

Source initiates with exact Destination Bootstrap Code.

Flow: resolve code → expiry/replay checks → challenge bound to source/dest/License → Device fingerprints → owner confirmation (both ends / non-TTY flags) → issue mTLS pair certs → persist signed migration-pair object (24h).

Primary trust: Device Authorization + application-signed objects + mTLS. SSH optional admin only.
