# shellcheck shell=bash

soviez_migration_landing_security_headers_block() {
  cat <<'EOF'
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header X-Frame-Options "DENY" always;
    add_header Content-Security-Policy "default-src 'none'; img-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'" always;
EOF
}
