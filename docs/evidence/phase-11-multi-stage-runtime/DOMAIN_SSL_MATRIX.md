# DOMAIN_SSL_MATRIX

| Check | Status |
|-------|--------|
| Domain mandatory + unique | ✅ |
| DNS validate | ✅ (fixture `SOVIEZ_STAGE_DNS_OK`) |
| Trusted CA chain required | ✅ |
| Self-signed rejected without CA | ✅ unit `soviez_ssl_validate_chain` |
| Nginx stub written | ✅ test mode |

