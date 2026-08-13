# shellcheck shell=bash
# Official ORM activation: key never as process argv; never logged; brief 0600 file only.

soviez_license_activate_via_odoo() {
  local web_container="$1"
  local db_name="$2"
  local activation_key="$3"

  if [[ -z "$activation_key" ]]; then
    soviez_die "$SOVIEZ_ERR_LICENSE" "Activation key missing"
  fi

  local stub_script="${SOVIEZ_ODOO_STUB:-}"
  if [[ -n "$stub_script" && -x "$stub_script" ]]; then
    printf '%s\n' "$activation_key" | "$stub_script" "$web_container" "$db_name"
    return 0
  fi

  if [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]]; then
    local marker="$SOVIEZ_ROOT/stubs/activation-${db_name}.invoked"
    mkdir -p "$SOVIEZ_ROOT/stubs"
    # Do NOT write the key into the marker.
    printf 'container=%s\ndb=%s\nstdin=1\n' "$web_container" "$db_name" > "$marker"
    return 0
  fi

  # Stage key into container via stdin→file (0600), then call official ORM method.
  local remote_key="/tmp/.soviez_activate_$$"
  if ! printf '%s' "$activation_key" | docker exec -i "$web_container" \
    bash -c "umask 077; cat > '${remote_key}' && chmod 600 '${remote_key}'"; then
    soviez_die "$SOVIEZ_ERR_LICENSE" "Failed to stage activation material"
  fi

  # NOTE: remote_key path is installer-generated (/tmp/.soviez_activate_$$) — not secret content.
  if ! docker exec "$web_container" odoo shell -d "$db_name" --no-http <<EOF
from pathlib import Path
p = Path("${remote_key}")
key = p.read_text(encoding="utf-8").strip()
p.write_text("", encoding="utf-8")
try:
    p.unlink()
except OSError:
    pass
env["soviez.license.mixin"].action_activate_soviez_license(key)
EOF
  then
    docker exec "$web_container" rm -f "$remote_key" 2>/dev/null || true
    soviez_die "$SOVIEZ_ERR_LICENSE" "ORM activation failed"
  fi
  docker exec "$web_container" rm -f "$remote_key" 2>/dev/null || true
}
