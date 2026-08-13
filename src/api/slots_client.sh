# shellcheck shell=bash

soviez_slots_reserve() {
  local idempotency_key="$1"
  local body
  body="$(SOVIEZ_IDEM="$idempotency_key" python3 - <<'PY'
import json, os
print(json.dumps({"idempotency_key": os.environ["SOVIEZ_IDEM"], "operation_type": "new"}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/reserve" "$body"
}

soviez_slots_instance_provisioned() {
  local slot_id="$1"
  local body
  body="$(SOVIEZ_SLOT="$slot_id" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/instance-provisioned" "$body"
}

soviez_slots_activation_method() {
  local slot_id="$1"
  local method="$2"
  local body
  body="$(SOVIEZ_SLOT="$slot_id" SOVIEZ_METHOD="$method" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"], "method": os.environ["SOVIEZ_METHOD"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/activation-method" "$body"
}

soviez_slots_bind_fingerprint() {
  local slot_id="$1"
  local fingerprint="$2"
  local body
  body="$(SOVIEZ_SLOT="$slot_id" SOVIEZ_FP="$fingerprint" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"], "fingerprint": os.environ["SOVIEZ_FP"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/bind-fingerprint" "$body"
}

soviez_slots_issue_license() {
  local slot_id="$1"
  local body
  body="$(SOVIEZ_SLOT="$slot_id" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/issue-license" "$body"
}

soviez_slots_activation_ack() {
  local slot_id="$1"
  local body
  body="$(SOVIEZ_SLOT="$slot_id" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"], "status": "activated"}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/activation-ack" "$body"
}

soviez_slots_release() {
  local slot_id="$1"
  local body
  body="$(SOVIEZ_SLOT="$slot_id" python3 - <<'PY'
import json, os
print(json.dumps({"slot_id": os.environ["SOVIEZ_SLOT"]}, separators=(",", ":")))
PY
)"
  soviez_http_signed_post_json "/api/installer/slots/release" "$body"
}
