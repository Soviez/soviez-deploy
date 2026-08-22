# Contradiction Matrix AFTER

| Rule | Pattern | Violations (active) |
|------|---------|----------------------|
| C01 | byte-identical.*customer|customers.*byte-identical | 0 |
| C02 | Use.*\./dist/soviez|run \./dist | 0 |
| C03 | workers=0 only|only supported.*workers.?0 | 0 |
| C04 | 8072 is never|8072 unsupported|never.*8072 | 0 |
| C05 | --formworkers | 0 |
| C06 | latest.*deployment authority|deploy.*:latest | 0 |
| C07 | installs Webmin|install Webmin | 0 |
| C08 | support expiry.*stop.*Production|expired support stops | 0 |
| C09 | ClamAV replaces YARA|YARA replaces ClamAV | 0 |
| C10 | Stripe is the.*authority|Stripe.*authoritative | 0 |
| C11 | monthly.*new customer|new sales.*monthly | 0 |
| C12 | Odoo.*superuser.*normal|normal.*superuser | 0 |

ACTIVE_DOCUMENT_CONTRADICTIONS = sum of material violations (manual review)
