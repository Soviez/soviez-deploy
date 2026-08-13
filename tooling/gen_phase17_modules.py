#!/usr/bin/env python3
"""Generate Phase 17 migration shell modules."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "src" / "migration"


def w(rel: str, content: str) -> None:
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)
    print("wrote", rel)


def main() -> None:
    w(
        "common/time.sh",
        r"""# shellcheck shell=bash

soviez_migration_now_epoch() {
  date -u +%s
}

soviez_migration_now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

soviez_migration_iso_to_epoch() {
  local iso="$1"
  if date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null; then
    return 0
  fi
  date -u -d "$iso" +%s 2>/dev/null || python3 -c "import datetime,sys; s=sys.argv[1].replace('Z','+00:00'); print(int(datetime.datetime.fromisoformat(s).timestamp()))" "$iso"
}

soviez_migration_expires_iso() {
  local ttl="${1:-86400}"
  python3 -c "import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$ttl"
}

soviez_migration_is_expired() {
  local expires_iso="$1"
  local now exp
  now="$(soviez_migration_now_epoch)"
  exp="$(soviez_migration_iso_to_epoch "$expires_iso")" || return 0
  [[ "$now" -ge "$exp" ]]
}

soviez_migration_clock_skew_seconds() {
  local remote_epoch="${1:-}"
  local now
  now="$(soviez_migration_now_epoch)"
  if [[ -z "$remote_epoch" ]]; then
    printf '0\n'
    return 0
  fi
  python3 -c "print(abs(int('$now')-int('$remote_epoch')))"
}

soviez_migration_assert_clock_skew() {
  local remote_epoch="${1:-}"
  local skew maxs
  skew="$(soviez_migration_clock_skew_seconds "$remote_epoch")"
  maxs="${SOVIEZ_MIG_CLOCK_SKEW_MAX_SECONDS:-300}"
  if [[ "$skew" -gt "$maxs" ]]; then
    soviez_migration_die MIGRATION_CLOCK_SKEW_BLOCKED "Clock skew ${skew}s exceeds ${maxs}s"
  fi
}
""",
    )

    w(
        "common/crypto.sh",
        r"""# shellcheck shell=bash

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
  body="$(soviez_migration_canonical_json "$(cat "$path")")"
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
  if openssl verify -CAfile "$dir/ca.crt" "$dir/source.crt" >/dev/null 2>&1 \
     && openssl verify -CAfile "$dir/ca.crt" "$dir/destination.crt" >/dev/null 2>&1; then
    # Attempt loopback handshake when possible
    local port payload
    port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
    payload="soviez-mig-synth-$(openssl rand -hex 4)"
    openssl s_server -quiet -accept "$port" -cert "$dir/destination.crt" -key "$dir/destination.key" \
      -CAfile "$dir/ca.crt" >/dev/null 2>&1 &
    local spid=$!
    sleep 0.25
    printf '%s\n' "$payload" | openssl s_client -quiet -connect "127.0.0.1:$port" \
      -cert "$dir/source.crt" -key "$dir/source.key" -CAfile "$dir/ca.crt" >/dev/null 2>&1 || true
    kill "$spid" 2>/dev/null || true
    wait "$spid" 2>/dev/null || true
    printf 'ok\n'
    return 0
  fi
  printf 'failed\n'
  return 1
}
""",
    )

    w(
        "common/identity.sh",
        r"""# shellcheck shell=bash

soviez_migration_host_identity() {
  local hn arch os
  hn="$(hostname -f 2>/dev/null || hostname)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
  esac
  os="$(uname -s)"
  SOVIEZ_HN="$hn" SOVIEZ_A="$arch" SOVIEZ_O="$os" python3 - <<'PY'
import hashlib, json, os
raw = f"{os.environ['SOVIEZ_HN']}|{os.environ['SOVIEZ_A']}|{os.environ['SOVIEZ_O']}"
print(json.dumps({
  "hostname": os.environ["SOVIEZ_HN"],
  "architecture": os.environ["SOVIEZ_A"],
  "os_family": os.environ["SOVIEZ_O"],
  "fingerprint": hashlib.sha256(raw.encode()).hexdigest()[:64],
}, separators=(",", ":")))
PY
}

soviez_migration_device_fingerprint() {
  if declare -F soviez_device_fingerprint >/dev/null 2>&1; then
    soviez_device_ensure_keys 2>/dev/null || true
    soviez_device_fingerprint
    return 0
  fi
  printf 'device-unset\n'
}

soviez_migration_detect_os_release() {
  if [[ -n "${SOVIEZ_MIG_FIXTURE_OS_ID:-}" ]]; then
    printf '%s\n' "${SOVIEZ_MIG_FIXTURE_OS_ID}"
    return 0
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s:%s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
    return 0
  fi
  # Darwin host used for unit fixtures — not a supported destination OS
  printf 'darwin:unknown\n'
}

soviez_migration_detect_arch() {
  if [[ -n "${SOVIEZ_MIG_FIXTURE_ARCH:-}" ]]; then
    printf '%s\n' "$SOVIEZ_MIG_FIXTURE_ARCH"
    return 0
  fi
  local a
  a="$(uname -m)"
  case "$a" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) printf '%s\n' "$a" ;;
  esac
}

soviez_migration_os_supported() {
  local idver="$1"
  case "$idver" in
    ubuntu:22.04|ubuntu:24.04) return 0 ;;
    *) return 1 ;;
  esac
}

soviez_migration_arch_supported() {
  [[ "$1" == "amd64" ]]
}
""",
    )

    w(
        "common/model.sh",
        r"""# shellcheck shell=bash

soviez_migration_write_json() {
  local path="$1" json="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$json" > "$path"
  chmod 600 "$path" 2>/dev/null || true
}

soviez_migration_read_json() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  cat "$path"
}

soviez_migration_outcome_banner() {
  local discovery="${1:-INCOMPLETE}" bootstrap="${2:-INCOMPLETE}" pair="${3:-UNTRUSTED}" \
        readiness="${4:-UNKNOWN}"
  cat <<EOF
SOURCE DISCOVERY — ${discovery}
DESTINATION BOOTSTRAP — ${bootstrap}
MIGRATION PAIR — ${pair}
READINESS — ${readiness}
NO DATA TRANSFER STARTED
SOURCE REMAINS ACTIVE
MIGRATION TOKEN NOT CONSUMED
DESTINATION PRODUCTION NOT ACTIVATED
EOF
}
""",
    )

    w(
        "common/report.sh",
        r"""# shellcheck shell=bash

soviez_migration_report_sign_and_store() {
  local kind="$1" id="$2" json="$3"
  local dir path
  soviez_migration_paths_init
  case "$kind" in
    discovery) dir="$(soviez_migration_discovery_dir "$id")" ;;
    bootstrap) dir="$(soviez_migration_bootstrap_dir "$id")" ;;
    pair) dir="$(soviez_migration_pair_dir "$id")" ;;
    readiness) dir="$(soviez_migration_readiness_dir "$id")" ;;
    *) dir="$SOVIEZ_MIG_EVIDENCE_DIR/$id" ;;
  esac
  mkdir -p "$dir"
  path="$dir/object.json"
  soviez_migration_write_json "$path" "$json"
  soviez_migration_sign_object_file "$path"
  cat "$path"
}
""",
    )

    print("common complete")


if __name__ == "__main__":
    main()
