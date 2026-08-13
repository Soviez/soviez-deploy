# shellcheck shell=bash
# Security Gate S4 — fresh destination infrastructure secrets.

soviez_q_generate_fresh_secrets() {
  local qid="$1"
  local d sf
  d="$(soviez_q_dir "$qid")"
  sf="$d/secrets/infra.env"
  mkdir -p "$d/secrets"
  chmod 700 "$d/secrets"
  if [[ -f "$sf" && "${SOVIEZ_Q_ROTATE_SECRETS:-0}" != "1" ]]; then
    printf '%s\n' "$sf"
    return 0
  fi
  python3 - "$sf" <<'PY'
import secrets,string,os,sys
a=string.ascii_letters+string.digits
def gen(n=32): return "".join(secrets.choice(a) for _ in range(n))
path=sys.argv[1]
open(path,"w").write("\n".join([
  f"SOVIEZ_Q_PG_ADMIN_PASSWORD={gen()}",
  f"SOVIEZ_Q_PG_APP_PASSWORD={gen()}",
  f"SOVIEZ_Q_ODOO_ADMIN_PASSWD={gen()}",
  f"SOVIEZ_Q_RUNTIME_SECRET={gen(40)}",
  f"SOVIEZ_Q_MIGRATION_TEMP_SECRET={gen()}",
  f"SOVIEZ_Q_REGISTRY_TEMP_SECRET={gen()}",
  f"SOVIEZ_Q_TRANSFER_TEMP_SECRET={gen()}",
])+"\n")
os.chmod(path, 0o600)
print(path)
PY
}

soviez_q_assert_secrets_fresh_vs_source() {
  local qid="$1" source_secrets_file="${2:-}"
  local sf
  sf="$(soviez_q_dir "$qid")/secrets/infra.env"
  [[ -f "$sf" ]] || return 1
  [[ -n "$source_secrets_file" && -f "$source_secrets_file" ]] || return 0
  python3 - "$sf" "$source_secrets_file" <<'PY'
import sys
dst=dict(l.strip().split("=",1) for l in open(sys.argv[1]) if "=" in l and not l.startswith("#"))
src=dict(l.strip().split("=",1) for l in open(sys.argv[2]) if "=" in l and not l.startswith("#"))
src_vals=set(src.values())
for k,v in dst.items():
  if v and v in src_vals:
    raise SystemExit(f"reused secret: {k}")
print("FRESH")
PY
}
