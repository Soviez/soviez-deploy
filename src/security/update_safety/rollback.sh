# shellcheck shell=bash
# Security Gate S5 — update rollback triggers (never restore insecure posture).

soviez_s5_should_rollback() {
  local validation_json="$1"
  if [[ -z "$validation_json" || ! -f "$validation_json" ]]; then
    echo true
    return 0
  fi
  python3 - "$validation_json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
# Material failure keys / statuses that must trigger rollback.
material_fields=(
  "odoo_pg","dns","outbound","ports_protected","nginx_upstream","pdf",
  "semantic_diff","docker_restart","overall"
)
fail_tokens={"FAIL","FAILED","CRITICAL"}
# Benign version-string diffs alone must not trigger.
if m.get("benign_version_diff_only") is True:
  print("false"); sys.exit(0)
checks=m.get("checks") or m
for k in material_fields:
  v=str((checks.get(k) if isinstance(checks,dict) else "") or m.get(k) or "").upper()
  if v in fail_tokens:
    print("true"); sys.exit(0)
if str(m.get("overall","")).upper() in fail_tokens:
  print("true"); sys.exit(0)
# Explicit material_failures list
for item in (m.get("material_failures") or []):
  if item:
    print("true"); sys.exit(0)
print("false")
PY
}

soviez_s5_assert_rollback_not_insecure() {
  # Never restore SUPERUSER grants or public 8069/5432 bindings during rollback.
  local plan="${1:-}"
  local bad=0

  if [[ -n "$plan" && -f "$plan" ]]; then
    if grep -Eiq 'SUPERUSER|CREATEROLE|pg_execute_server_program|0\.0\.0\.0:8069|0\.0\.0\.0:5432|-p[[:space:]]*8069|-p[[:space:]]*5432' "$plan"; then
      # Allow mentions in deny/assert comments.
      if ! grep -Eiq 'NEVER|must not|forbid|reject|assert.*not' "$plan"; then
        echo "[error] security:SEC_CRIT_SECURITY_STATE_UNKNOWN: rollback plan may restore insecure state" >&2
        bad=1
      fi
    fi
  fi

  # Live container posture check when available.
  local odoo="${SOVIEZ_SEC_ODOO_CONTAINER:-}"
  local pg="${SOVIEZ_SEC_PG_CONTAINER:-}"
  if declare -F soviez_s5_check_ports_protected >/dev/null 2>&1; then
    if ! soviez_s5_check_ports_protected "$odoo" "$pg" >/dev/null 2>&1; then
      echo "[error] security:SEC_CRIT_PUBLIC_ODOO_PORT: rollback left public ports" >&2
      bad=1
    fi
  fi

  if [[ "$bad" -ne 0 ]]; then
    echo FAIL
    return 1
  fi
  echo PASS
  return 0
}
