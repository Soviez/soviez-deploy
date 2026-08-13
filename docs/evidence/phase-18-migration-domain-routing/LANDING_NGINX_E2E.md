# LANDING_NGINX_E2E

E2E prepares landing then serves via disposable nginx container (Docker volume + `docker cp`; Colima bind mounts flaky).

Asserts HTTP body reachability for migration site. Covered by `test_phase18_domain_dns_landing_tls_e2e.sh`.
