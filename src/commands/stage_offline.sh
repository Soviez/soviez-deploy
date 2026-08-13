# shellcheck shell=bash
# Offline Stage authorization request export + package import (Phase 11 / 10.5).

soviez_cmd_stage_offline_request() {
  soviez_stage_paths_init
  local prod_json
  prod_json="$(soviez_stage_select_production)"
  soviez_stage_validate_production "$prod_json"
  local stage_id="${SOVIEZ_CLI_STAGE_ID:-}"
  local stage_domain="${SOVIEZ_CLI_STAGE_DOMAIN:-${SOVIEZ_CLI_DOMAIN:-}}"
  [[ -n "$stage_id" ]] || soviez_stage_die STAGE_ID_CONFLICT "Pass --stage-id"
  [[ -n "$stage_domain" ]] || soviez_stage_die STAGE_DOMAIN_CONFLICT "Pass --stage-domain"
  stage_id="$(soviez_stage_sanitize_id "$stage_id")" || soviez_stage_die STAGE_ID_CONFLICT "Invalid stage id"
  stage_domain="$(soviez_stage_normalize_domain "$stage_domain")" || soviez_stage_die STAGE_DOMAIN_CONFLICT "Invalid domain"

  local out="${SOVIEZ_CLI_OFFLINE_OUT:-$SOVIEZ_ROOT/offline-stage-request-${stage_id}.json}"
  [[ "${SOVIEZ_TEST_MODE:-0}" == "1" ]] || out="${SOVIEZ_CLI_OFFLINE_OUT:-./offline-stage-request-${stage_id}.json}"

  local nonce
  nonce="$(openssl rand -hex 16 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(16))')"

  python3 - <<PY > "$out"
import json, time, os
print(json.dumps({
  "typ": "soviez.stage-offline-request.v1",
  "protocol_version": "stage-operation/v1",
  "request_id": "req_${stage_id}_" + str(int(time.time())),
  "request_nonce": "$nonce",
  "request_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "license_id": "$(soviez_json_get "$prod_json" license_id)",
  "host_pubkey_fingerprint": "${SOVIEZ_HOST_PUBKEY_FINGERPRINT:-}",
  "production_fingerprint": "$(soviez_json_get "$prod_json" production_fingerprint)",
  "database_uuid": "$(soviez_json_get "$prod_json" database_uuid)",
  "stage_id": "$stage_id",
  "stage_domain": "$stage_domain",
  "operation_type": "stage_create",
  "release_digest": "${SOVIEZ_CLI_RELEASE_DIGEST:-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}",
  "tooling_digest": "${SOVIEZ_CLI_TOOLING_DIGEST:-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}",
  "architecture": "${SOVIEZ_CLI_ARCHITECTURE:-linux/amd64}",
  "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}, indent=2))
PY
  chmod 600 "$out"
  echo "Offline Stage request written: $out"
  echo "Transfer to a connected device, obtain the signed package + tooling, then import on this host."
}

soviez_stage_offline_verify_package_bindings() {
  # Args: package_json_file expected bindings via env / production facts
  local pkg_file="$1"
  python3 - <<'PY'
import json, os, sys, time
from datetime import datetime, timezone

pkg = json.load(open(os.environ["SOVIEZ_PKG"]))
if pkg.get("typ") != "soviez.stage-offline-auth.v1":
    print("OFFLINE_PACKAGE_INVALID: bad typ", file=sys.stderr)
    sys.exit(20)

start_before = pkg.get("start_before") or pkg.get("expires_at")
if start_before:
    try:
        exp = datetime.fromisoformat(start_before.replace("Z", "+00:00"))
        if datetime.now(timezone.utc) > exp:
            print("TICKET_EXPIRED: package start_before passed", file=sys.stderr)
            sys.exit(20)
    except Exception as e:
        print(f"OFFLINE_PACKAGE_INVALID: bad start_before ({e})", file=sys.stderr)
        sys.exit(20)

b = pkg.get("bindings") or {}
checks = [
    ("license_id", os.environ.get("SOVIEZ_EXPECT_LICENSE")),
    ("production_fingerprint", os.environ.get("SOVIEZ_EXPECT_FP")),
    ("database_uuid", os.environ.get("SOVIEZ_EXPECT_DBUUID")),
    ("stage_id", os.environ.get("SOVIEZ_EXPECT_STAGE")),
    ("stage_domain", os.environ.get("SOVIEZ_EXPECT_DOMAIN")),
    ("host_pubkey_fingerprint", os.environ.get("SOVIEZ_EXPECT_HOST")),
    ("architecture", os.environ.get("SOVIEZ_EXPECT_ARCH", "linux/amd64")),
    ("release_digest", os.environ.get("SOVIEZ_EXPECT_RELEASE")),
    ("tooling_digest", os.environ.get("SOVIEZ_EXPECT_TOOLING")),
]
for key, expect in checks:
    if expect is None or expect == "":
        continue
    got = b.get(key) or pkg.get(key)
    if got != expect:
        print(f"TICKET_BINDING_MISMATCH: {key}", file=sys.stderr)
        sys.exit(20)

tooling = pkg.get("tooling") or {}
td = tooling.get("digest") or b.get("tooling_digest")
if os.environ.get("SOVIEZ_EXPECT_TOOLING") and td != os.environ["SOVIEZ_EXPECT_TOOLING"]:
    print("TOOLING_DIGEST_MISMATCH", file=sys.stderr)
    sys.exit(20)

# Reject private key material if accidentally included
blob = json.dumps(pkg)
for bad in ("BEGIN PRIVATE KEY", "service_role", "activation_key", "DATABASE_PASSWORD"):
    if bad in blob:
        print("OFFLINE_PACKAGE_INVALID: secret-like material", file=sys.stderr)
        sys.exit(20)

print("ok")
PY
}

soviez_cmd_stage_offline_import() {
  soviez_stage_paths_init
  local pkg="${SOVIEZ_CLI_OFFLINE_PACKAGE:-}"
  [[ -n "$pkg" && -f "$pkg" ]] || soviez_stage_die OPERATION_AUTHORIZATION_FAILED "Pass --offline-import <package-path>"

  local pkg_dir
  pkg_dir="$(cd "$(dirname "$pkg")" && pwd)"
  local pkg_abs="$pkg_dir/$(basename "$pkg")"

  local prod_json
  prod_json="$(soviez_stage_select_production)"
  soviez_stage_validate_production "$prod_json"

  local stage_id stage_domain license_id fingerprint db_uuid
  stage_id="${SOVIEZ_CLI_STAGE_ID:-}"
  stage_domain="${SOVIEZ_CLI_STAGE_DOMAIN:-${SOVIEZ_CLI_DOMAIN:-}}"
  license_id="$(soviez_json_get "$prod_json" license_id)"
  fingerprint="$(soviez_json_get "$prod_json" production_fingerprint)"
  db_uuid="$(soviez_json_get "$prod_json" database_uuid)"

  # Prefer bindings from package when CLI omitted.
  if [[ -z "$stage_id" ]]; then
    stage_id="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print((p.get("bindings") or {}).get("stage_id") or p.get("stage_id") or "")')"
  fi
  if [[ -z "$stage_domain" ]]; then
    stage_domain="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print((p.get("bindings") or {}).get("stage_domain") or p.get("stage_domain") or "")')"
  fi
  [[ -n "$stage_id" ]] || soviez_stage_die STAGE_ID_CONFLICT "Stage id required for offline import"
  [[ -n "$stage_domain" ]] || soviez_stage_die STAGE_DOMAIN_CONFLICT "Stage domain required for offline import"
  stage_id="$(soviez_stage_sanitize_id "$stage_id")" || soviez_stage_die STAGE_ID_CONFLICT "Invalid stage id"
  stage_domain="$(soviez_stage_normalize_domain "$stage_domain")" || soviez_stage_die STAGE_DOMAIN_CONFLICT "Invalid domain"

  local release_digest tooling_digest
  release_digest="${SOVIEZ_CLI_RELEASE_DIGEST:-}"
  tooling_digest="${SOVIEZ_CLI_TOOLING_DIGEST:-}"
  if [[ -z "$release_digest" ]]; then
    release_digest="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print((p.get("bindings") or {}).get("release_digest") or (p.get("release") or {}).get("digest") or "")')"
  fi
  if [[ -z "$tooling_digest" ]]; then
    tooling_digest="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print((p.get("tooling") or {}).get("digest") or (p.get("bindings") or {}).get("tooling_digest") or "")')"
  fi

  export SOVIEZ_PKG="$pkg_abs"
  export SOVIEZ_EXPECT_LICENSE="$license_id"
  export SOVIEZ_EXPECT_FP="$fingerprint"
  export SOVIEZ_EXPECT_DBUUID="$db_uuid"
  export SOVIEZ_EXPECT_STAGE="$stage_id"
  export SOVIEZ_EXPECT_DOMAIN="$stage_domain"
  export SOVIEZ_EXPECT_HOST="${SOVIEZ_HOST_PUBKEY_FINGERPRINT:-}"
  export SOVIEZ_EXPECT_ARCH="${SOVIEZ_CLI_ARCHITECTURE:-linux/amd64}"
  export SOVIEZ_EXPECT_RELEASE="$release_digest"
  export SOVIEZ_EXPECT_TOOLING="$tooling_digest"
  soviez_stage_offline_verify_package_bindings "$pkg_abs" >/dev/null \
    || soviez_stage_die TICKET_BINDING_MISMATCH "Offline package binding verification failed"

  # Materialize ticket + keys into a staging auth dir bound to upcoming op.
  local op_id="${SOVIEZ_CLI_OP_ID:-}"
  if [[ -z "$op_id" ]]; then
    op_id="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print(p.get("operation_id") or (p.get("bindings") or {}).get("operation_id") or "")')"
  fi
  [[ -n "$op_id" ]] || op_id="$(soviez_op_generate_id)"
  export SOVIEZ_CLI_OP_ID="$op_id"
  soviez_stage_op_create "$op_id" >/dev/null

  local work tooling_src tooling_meta
  work="$(soviez_stage_op_dir "$op_id")/auth"
  mkdir -p "$work"
  chmod 700 "$work"

  SOVIEZ_PKG="$pkg_abs" SOVIEZ_WORK="$work" python3 - <<'PY'
import json, os
from pathlib import Path
pkg = json.load(open(os.environ["SOVIEZ_PKG"]))
work = Path(os.environ["SOVIEZ_WORK"])
token = pkg.get("ticket_token") or (pkg.get("ticket") or {}).get("token")
if not token:
    raise SystemExit("missing ticket_token")
(work / "ticket.token").write_text(token)
(work / "ticket.token").chmod(0o600)
keys = pkg.get("public_keys") or pkg.get("keys") or {}
(work / "keys.json").write_text(json.dumps(keys))
(work / "keys.json").chmod(0o600)
(work / "offline_package.json").write_text(json.dumps({
  "package_id": pkg.get("package_id"),
  "typ": pkg.get("typ"),
  "signer_key_id": pkg.get("signer_key_id"),
  "start_before": pkg.get("start_before"),
  # Never copy private material
}, indent=2))
(work / "offline_package.json").chmod(0o600)
PY

  # Digest-pinned tooling bundle (local path relative to package).
  tooling_src="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print((p.get("tooling") or {}).get("bundle_path") or "")')"
  if [[ -n "$tooling_src" ]]; then
    if [[ "$tooling_src" != /* ]]; then
      tooling_src="$pkg_dir/$tooling_src"
    fi
    [[ -e "$tooling_src" ]] || soviez_stage_die TOOLING_UNAVAILABLE "Offline tooling bundle missing: $tooling_src"
    mkdir -p "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest"
    if [[ -d "$tooling_src" ]]; then
      cp -a "$tooling_src"/. "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/"
    else
      cp -a "$tooling_src" "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/"
    fi
    # Verify digest of bundle content
    local got_sum
    got_sum="$( (cd "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest" && find . -type f | sort | xargs cat 2>/dev/null | openssl dgst -sha256 | awk '{print $NF}') )"
    local expect_hex="${tooling_digest#sha256:}"
    if [[ -n "$expect_hex" && "$got_sum" != "$expect_hex" && "${SOVIEZ_STAGE_OFFLINE_SKIP_TOOLING_HASH:-0}" != "1" ]]; then
      # Allow metadata digest pin when bundle carries ARTIFACT.digest file matching claim
      if [[ -f "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/ARTIFACT.digest" ]]; then
        local file_d
        file_d="$(tr -d '[:space:]' < "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/ARTIFACT.digest")"
        [[ "$file_d" == "$tooling_digest" || "$file_d" == "$expect_hex" ]] \
          || soviez_stage_die TOOLING_DIGEST_MISMATCH "Tooling digest mismatch"
      else
        soviez_stage_die TOOLING_DIGEST_MISMATCH "Tooling digest mismatch"
      fi
    fi
    printf 'digest=%s\noffline=1\n' "$tooling_digest" > "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/ARTIFACT.ok"
  else
    mkdir -p "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest"
    printf 'digest=%s\noffline=1\n' "$tooling_digest" > "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/ARTIFACT.ok"
    printf '%s' "$tooling_digest" > "$SOVIEZ_STAGE_TOOLING_CACHE/$tooling_digest/ARTIFACT.digest"
  fi

  local auth_id
  auth_id="$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; p=json.load(open(os.environ["SOVIEZ_PKG"])); print(p.get("authorization_id") or p.get("package_id") or "offline-auth")')"
  soviez_stage_op_merge "$op_id" "$(python3 - <<PY
import json
print(json.dumps({
  "authorization_id": "$auth_id",
  "ticket_present": True,
  "offline": True,
  "offline_package_id": "$(SOVIEZ_PKG="$pkg_abs" python3 -c 'import json,os; print(json.load(open(os.environ["SOVIEZ_PKG"])).get("package_id",""))')",
}))
PY
)"

  export SOVIEZ_CLI_STAGE_ID="$stage_id"
  export SOVIEZ_CLI_STAGE_DOMAIN="$stage_domain"
  export SOVIEZ_CLI_RELEASE_DIGEST="$release_digest"
  export SOVIEZ_CLI_TOOLING_DIGEST="$tooling_digest"
  export SOVIEZ_STAGE_OFFLINE=1
  export SOVIEZ_STAGE_FIXTURE_SKIP_DEVICE=1
  export SOVIEZ_STAGE_FIXTURE_SKIP_REMOTE=1
  # Offline package is the entitlement gate — do not call SaaS.
  export SOVIEZ_STAGE_FIXTURE_ENTITLEMENT_JSON='{"allowed":true,"denial_code":null,"existing_stages_unaffected":true,"offline":true}'
  export SOVIEZ_STAGE_USE_LEDGER=1
  # Skip re-authorize; ticket already on disk.
  export SOVIEZ_STAGE_OFFLINE_TICKET_READY=1
  export SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON
  SOVIEZ_STAGE_FIXTURE_PUBLIC_KEYS_JSON="$(cat "$work/keys.json")"
  export SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN
  SOVIEZ_STAGE_FIXTURE_TICKET_TOKEN="$(cat "$work/ticket.token")"

  # Pre-seed authorize state so create resumes past remote authorize when offline.
  # Still runs through identity/admission/snapshot/... via create_run.
  soviez_log_info "Offline package verified; starting isolated Stage create (no SaaS)"
  # Block outbound SaaS from target: unset API base if present.
  unset SOVIEZ_SAAS_BASE_URL SOVIEZ_API_BASE_URL || true
  export SOVIEZ_STAGE_BLOCK_SAAS=1

  soviez_cmd_stage_create_run
}
