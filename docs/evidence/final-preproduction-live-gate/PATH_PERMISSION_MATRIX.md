# PATH_PERMISSION_MATRIX

| Path | Mode | Owner | Result |
|---|---|---|---|
| /usr/local/bin/soviez.sh | 755 | root:root | PASS |
| /opt/soviez/platform/current/soviez.sh | 755 | root:root | PASS |
| /opt/soviez/platform/current/trust/*.pub | public | root | PASS |
| Private keys in VM/evidence | n/a | n/a | PASS (not copied) |

Blocker: platform install uses invalid chmod -p on Ubuntu (should be mkdir -p), breaking --platform-install apply.
