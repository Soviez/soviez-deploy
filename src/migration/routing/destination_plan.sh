# shellcheck shell=bash

soviez_migration_routing_disabled_erp_template() {
  local out_dir="$1"
  mkdir -p "$out_dir"
  cat > "$out_dir/erp-route.conf.disabled" <<'EOF'
# SOVIEZ migration routing — ERP upstream DISABLED until Phase 21 cutover
# upstream odoo_erp { server 127.0.0.1:8069; }
# server {
#   listen 443 ssl;
#   server_name PRODUCTION_DOMAIN_PLACEHOLDER;
#   location / { proxy_pass http://odoo_erp; }
# }
EOF
  printf '%s\n' "$out_dir/erp-route.conf.disabled"
}
