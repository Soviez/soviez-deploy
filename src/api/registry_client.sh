# shellcheck shell=bash

soviez_registry_resolve_release() {
  local channel="$1"
  local body
  body="$(SOVIEZ_CHANNEL="$channel" python3 - <<'PY'
import json, os
print(json.dumps({"channel": os.environ["SOVIEZ_CHANNEL"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/registry/releases/resolve" "$body"
}

# Args: release_id digest [operation_id] [operation_type]
soviez_registry_create_pull_session() {
  local release_id="$1"
  local digest="$2"
  local operation_id="${3:-}"
  local operation_type="${4:-production_new}"
  if [[ -z "$operation_id" ]]; then
    operation_id="op-$(date -u +%Y%m%d%H%M%S)-$$"
  fi
  local idempotency_key
  idempotency_key="pull-${release_id}-${digest}-${operation_id}"
  local body
  body="$(
    SOVIEZ_RID="$release_id" SOVIEZ_DIGEST="$digest" \
    SOVIEZ_OP="$operation_id" SOVIEZ_OT="$operation_type" SOVIEZ_IK="$idempotency_key" \
    python3 - <<'PY'
import json, os
print(json.dumps({
  "release_id": os.environ["SOVIEZ_RID"],
  "digest": os.environ["SOVIEZ_DIGEST"],
  "operation_id": os.environ["SOVIEZ_OP"],
  "operation_type": os.environ["SOVIEZ_OT"],
  "idempotency_key": os.environ["SOVIEZ_IK"],
  "architecture": os.environ.get("SOVIEZ_ARCH", "amd64"),
  "protocol_version": "registry-pull/v1",
}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/registry/pull-sessions" "$body"
}

soviez_registry_refresh_pull_session() {
  local session_id="$1"
  local body
  body="$(SOVIEZ_SID="$session_id" python3 - <<'PY'
import json, os
print(json.dumps({"session_id": os.environ["SOVIEZ_SID"], "pull_session_id": os.environ["SOVIEZ_SID"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/registry/pull-sessions/refresh" "$body"
}

soviez_registry_complete_pull_session() {
  local session_id="$1"
  local body
  body="$(SOVIEZ_SID="$session_id" python3 - <<'PY'
import json, os
print(json.dumps({"session_id": os.environ["SOVIEZ_SID"], "pull_session_id": os.environ["SOVIEZ_SID"]}, separators=(",", ":")))
PY
)"
  # Non-fatal: older SaaS / test mocks may omit complete
  soviez_http_signed_post_json_soft "/api/installer/registry/pull-sessions/complete" "$body" >/dev/null || true
}

soviez_registry_revoke_pull_session() {
  local session_id="$1"
  local body
  body="$(SOVIEZ_SID="$session_id" python3 - <<'PY'
import json, os
print(json.dumps({"session_id": os.environ["SOVIEZ_SID"], "pull_session_id": os.environ["SOVIEZ_SID"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json_soft "/api/installer/registry/pull-sessions/revoke" "$body" >/dev/null || true
}

# Normalize SaaS create-session JSON into installer pull fields.
# Prints: session_id|username|password|gateway_url|repository|digest|image_ref
soviez_registry_session_fields() {
  local pull_json="$1"
  local gateway_fallback="${SOVIEZ_REGISTRY_GATEWAY_URL:-https://registry.soviez.com}"
  SOVIEZ_JSON_INPUT="$pull_json" SOVIEZ_GW="$gateway_fallback" python3 - <<'PY'
import json, os, sys
data = json.loads(os.environ["SOVIEZ_JSON_INPUT"])
gw = (data.get("gateway_url") or os.environ.get("SOVIEZ_GW") or "").rstrip("/")
session = data.get("pull_session_id") or data.get("session_id") or ""
user = data.get("registry_username") or data.get("username") or session
password = data.get("pull_ticket") or data.get("client_token") or data.get("password") or data.get("token") or ""
repo = data.get("repository") or ""
digest = data.get("digest") or ""
image_ref = data.get("image_ref") or ""
if not image_ref and repo and digest and gw:
    host = gw.split("://", 1)[-1].split("/")[0]
    image_ref = f"{host}/{repo}@{digest}"
print("|".join([session, user, password, gw, repo, digest, image_ref]))
PY
}
