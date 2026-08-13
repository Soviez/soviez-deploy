# shellcheck shell=bash

soviez_migration_landing_site_id() {
  local pair_id="$1"
  printf 'mig-landing-%s\n' "$pair_id"
}

soviez_migration_landing_write_content() {
  local site_dir="$1" pair_id="$2" migration_fqdn="$3"
  mkdir -p "$site_dir/www"
  cat > "$site_dir/www/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Migration in progress</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
  <main>
    <h1>Migration in progress</h1>
    <p>Your Soviez environment is being prepared on a dedicated migration subdomain.</p>
    <p>Operation reference: <code>$(printf '%s' "$pair_id" | sed 's/[&<>"]//g')</code></p>
    <p>No customer data is shown on this page. Contact your administrator for next steps.</p>
  </main>
</body>
</html>
EOF
  cat > "$site_dir/www/healthz" <<EOF
{"ok":true,"site":"$(printf '%s' "$migration_fqdn" | sed 's/[\\"]//g')"}
EOF
}
