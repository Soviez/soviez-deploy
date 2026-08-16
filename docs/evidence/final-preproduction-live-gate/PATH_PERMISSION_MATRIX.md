# PATH_PERMISSION_MATRIX

| Path | Mode | Owner | Result |
|---|---|---|---|
| /usr/local/bin/soviez.sh | 755 | root:root | PASS |
| /opt/soviez/platform/current/soviez.sh | 755 | root:root | PASS |
| /opt/soviez/platform/current/trust/*.pub | public only | root | PASS (no private keys) |
| Private keys in VM/evidence | — | — | PASS (not copied) |

Notes:
-  contains  (invalid on GNU chmod) which breaks  apply path after self-update decisions (see SELF_UPDATE evidence).
