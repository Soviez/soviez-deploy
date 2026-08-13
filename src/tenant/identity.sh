# shellcheck shell=bash

soviez_tenant_identity_create() {
  local op_id="$1"
  local tenant_id="${2:-tenant-${op_id}}"
  local identity_file="$SOVIEZ_TENANT_DIR/identity.json"
  mkdir -p "$SOVIEZ_TENANT_DIR"
  chmod 700 "$SOVIEZ_TENANT_DIR"
  printf '{"tenant_id":"%s","operation_id":"%s"}\n' "$tenant_id" "$op_id" > "$identity_file"
  chmod 600 "$identity_file"
  printf '%s' "$tenant_id"
}

soviez_tenant_identity_load() {
  local identity_file="$SOVIEZ_TENANT_DIR/identity.json"
  [[ -f "$identity_file" ]] || return 1
  soviez_json_get "$(cat "$identity_file")" "tenant_id"
}
