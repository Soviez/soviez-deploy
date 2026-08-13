# Miner / resource abuse detection

Detect: sustained CPU, xmrig names, stratum, /tmp|/dev/shm binaries, unknown high-load, IOC endpoints.

Response:
```text
detect → preserve evidence → alert → optionally quarantine
NOT blind kill/delete
```
