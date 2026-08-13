# Install / activation matrix

## Install
- Clean connected `--new` on Ubuntu 22.04 and 24.04 amd64
- Clean offline install path
- Docker/PG compatibility gates
- Production domain + trusted SSL
- Failure/retry/recovery (Docker down, disk, nginx -t fail)

## Activation
- Automatic on `--new`
- Manual activation
- Offline activation
- Negative: invalid License, invalid Device, slot conflict
- SaaS unavailable during/after activate (ERP remains)
- Support expired: ERP runtime valid; update entitlement denied as designed
- No hidden phone-home

Classes: REAL_DOCKER/POSTGRES/ODOO/NETWORK as applicable; AIRGAP for offline install/activate.
