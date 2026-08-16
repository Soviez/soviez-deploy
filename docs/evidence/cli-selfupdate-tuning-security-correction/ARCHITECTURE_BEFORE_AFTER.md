# Architecture before / after

| Area | Before | After |
|------|--------|-------|
| Public entry | Dual: pipe→legacy wizard; day-2 `./dist/soviez.sh` | Bootstrap→modular platform→`/usr/local/bin/soviez.sh` |
| Self-update | Legacy unsigned body replace | Signed manifest + SHA256 + atomic switch + re-exec |
| Workers | Certified workers=0 only | Automatic sizing; workers>0 when safe |
| WebSocket | `/websocket`→8069 | `/websocket`→8072 when multi-worker |
| Tune | `--formworkers` wizard | `soviez.sh --tune` |
| Malware | YARA + native | ClamAV + YARA + native + quarantine |
