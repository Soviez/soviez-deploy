# Automatic Deletion
The local scheduler scans retained Stage IDs, refreshes countdown/warnings/banner, and invokes deletion only when the calendar deadline is due. It performs no entitlement lookup or network call.

Deletion order is final backup, Safe Shield, stop container, Production health check, remove Stage Nginx/container/DB/filestore/volumes/network/config/secrets/unshared cert, tombstone, then inventory removal. It never uses global Docker prune.
