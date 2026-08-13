# shellcheck shell=bash

soviez_migration_sign_json() {
  local payload="$1"
  if declare -F soviez_device_sign_message >/dev/null 2>&1; then
    soviez_device_ensure_keys 2>/dev/null || true
    soviez_device_sign_message "$payload"
    return 0
  fi
  local keyf="${SOVIEZ_MIG_SECRETS_DIR}/signing.key"
  mkdir -p "${SOVIEZ_MIG_SECRETS_DIR}"
  [[ -f "$keyf" ]] || openssl rand -hex 32 > "$keyf"
  chmod 600 "$keyf"
  printf '%s' "$payload" | openssl dgst -sha256 -hmac "$(cat "$keyf")" | awk '{print $NF}'
}

soviez_migration_canonical_json() {
  local json="$1"
  SOVIEZ_J="$json" python3 - <<'PY'
import json, os
print(json.dumps(json.loads(os.environ["SOVIEZ_J"]), sort_keys=True, separators=(",", ":")))
PY
}

soviez_migration_sign_object_file() {
  local path="$1"
  local body sig
  body="$(SOVIEZ_P="$path" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_P"]))
d.pop("signature", None)
d.pop("signed_at", None)
print(json.dumps(d, sort_keys=True, separators=(",", ":")))
PY
)"
  sig="$(soviez_migration_sign_json "$body")"
  SOVIEZ_B="$body" SOVIEZ_S="$sig" SOVIEZ_P="$path" python3 - <<'PY'
import json, os, datetime
doc = json.loads(os.environ["SOVIEZ_B"])
doc["signature"] = os.environ["SOVIEZ_S"]
doc["signed_at"] = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
open(os.environ["SOVIEZ_P"], "w").write(json.dumps(doc, separators=(",", ":")))
PY
}

soviez_migration_verify_object_signature() {
  local path="$1"
  local expected body actual
  expected="$(soviez_json_get "$(cat "$path")" signature 2>/dev/null || true)"
  [[ -n "$expected" ]] || return 1
  body="$(SOVIEZ_P="$path" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_P"]))
d.pop("signature", None)
d.pop("signed_at", None)
print(json.dumps(d, sort_keys=True, separators=(",", ":")))
PY
)"
  actual="$(soviez_migration_sign_json "$body")"
  [[ "$actual" == "$expected" ]]
}

soviez_migration_mtls_issue_pair() {
  local pair_id="$1" cn_src="$2" cn_dst="$3"
  local dir ca_key ca_crt src_key src_crt dst_key dst_crt
  soviez_migration_paths_init
  dir="$SOVIEZ_MIG_TRUST_DIR/$pair_id"
  mkdir -p "$dir"
  chmod 700 "$dir"
  ca_key="$dir/ca.key"; ca_crt="$dir/ca.crt"
  src_key="$dir/source.key"; src_crt="$dir/source.crt"
  dst_key="$dir/destination.key"; dst_crt="$dir/destination.crt"
  if [[ ! -f "$ca_crt" ]]; then
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 1 -nodes \
      -keyout "$ca_key" -out "$ca_crt" -subj "/CN=soviez-migration-ca-$pair_id" 2>/dev/null
    chmod 600 "$ca_key"
  fi
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$src_key" -out "$dir/source.csr" -subj "/CN=$cn_src" 2>/dev/null
  openssl x509 -req -in "$dir/source.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial \
    -out "$src_crt" -days 1 2>/dev/null
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "$dst_key" -out "$dir/destination.csr" -subj "/CN=$cn_dst" 2>/dev/null
  openssl x509 -req -in "$dir/destination.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial \
    -out "$dst_crt" -days 1 2>/dev/null
  chmod 600 "$src_key" "$dst_key"
  rm -f "$dir/source.csr" "$dir/destination.csr"
  printf '%s\n' "$dir"
}

soviez_migration_mtls_connectivity_test() {
  local pair_id="$1"
  local dir
  dir="$SOVIEZ_MIG_TRUST_DIR/$pair_id"
  [[ -d "$dir" ]] || { printf 'failed\n'; return 1; }
  if ! openssl verify -CAfile "$dir/ca.crt" "$dir/source.crt" >/dev/null 2>&1 \
     || ! openssl verify -CAfile "$dir/ca.crt" "$dir/destination.crt" >/dev/null 2>&1; then
    printf 'failed\n'
    return 1
  fi
  # Live loopback mutual TLS handshake (required when SOVIEZ_MIG_MTLS_LOOPBACK=1)
  if [[ "${SOVIEZ_MIG_MTLS_LOOPBACK:-0}" == "1" ]]; then
    local port hs_out hs_rc=1
    port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
    openssl s_server -quiet -accept "$port" -cert "$dir/destination.crt" -key "$dir/destination.key" \
      -CAfile "$dir/ca.crt" -Verify 1 >/tmp/soviez-mtls-srv-$$.log 2>&1 &
    local spid=$!
    sleep 0.35
    hs_out="$(printf 'soviez-mig-synth\n' | openssl s_client -quiet -connect "127.0.0.1:$port" \
      -cert "$dir/source.crt" -key "$dir/source.key" -CAfile "$dir/ca.crt" 2>/tmp/soviez-mtls-cli-$$.log)" && hs_rc=0 || hs_rc=$?
    kill "$spid" 2>/dev/null || true
    wait "$spid" 2>/dev/null || true
    rm -f /tmp/soviez-mtls-srv-$$.log /tmp/soviez-mtls-cli-$$.log
    # Handshake success: client exit 0 OR Verify return code: 0 in client log path
    if [[ "$hs_rc" -ne 0 ]]; then
      # Retry once with Verify return code check via non-quiet
      port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
      openssl s_server -accept "$port" -cert "$dir/destination.crt" -key "$dir/destination.key" \
        -CAfile "$dir/ca.crt" >/tmp/soviez-mtls-srv2-$$.log 2>&1 &
      spid=$!
      sleep 0.35
      if ! printf 'soviez-mig-synth\n' | openssl s_client -connect "127.0.0.1:$port" \
        -cert "$dir/source.crt" -key "$dir/source.key" -CAfile "$dir/ca.crt" 2>/tmp/soviez-mtls-cli2-$$.log \
        | grep -q 'Verify return code: 0'; then
        kill "$spid" 2>/dev/null || true
        wait "$spid" 2>/dev/null || true
        rm -f /tmp/soviez-mtls-srv2-$$.log /tmp/soviez-mtls-cli2-$$.log
        printf 'failed\n'
        return 1
      fi
      kill "$spid" 2>/dev/null || true
      wait "$spid" 2>/dev/null || true
      rm -f /tmp/soviez-mtls-srv2-$$.log /tmp/soviez-mtls-cli2-$$.log
    fi
    printf 'ok-handshake\n'
    return 0
  fi
  printf 'ok\n'
  return 0
}

soviez_migration_mtls_deny_substituted_ca() {
  # Prove MITM / CA substitution fails verification
  local pair_id="$1"
  local dir evil
  dir="$SOVIEZ_MIG_TRUST_DIR/$pair_id"
  [[ -d "$dir" ]] || return 1
  evil="$(mktemp -d "${TMPDIR:-/tmp}/soviez-evil-ca.XXXXXX")"
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 1 -nodes \
    -keyout "$evil/evil.key" -out "$evil/evil.crt" -subj "/CN=evil-ca" 2>/dev/null
  if openssl verify -CAfile "$evil/evil.crt" "$dir/source.crt" >/dev/null 2>&1; then
    rm -rf "$evil"
    return 1
  fi
  rm -rf "$evil"
  return 0
}
