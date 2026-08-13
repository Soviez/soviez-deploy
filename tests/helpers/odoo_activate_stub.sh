#!/usr/bin/env bash
# Records stdin activation without echoing the key.
set -euo pipefail
container="$1"
db="$2"
marker_dir="${SOVIEZ_ROOT:?SOVIEZ_ROOT required}/stubs"
mkdir -p "$marker_dir"
read -r _key
printf 'container=%s\ndb=%s\nstdin=1\n' "$container" "$db" > "$marker_dir/odoo-activate-${db}.invoked"
