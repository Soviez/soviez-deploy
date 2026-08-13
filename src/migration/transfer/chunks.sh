# shellcheck shell=bash

soviez_migration_chunk_registry_path() {
  local op_id="$1"
  printf '%s/chunk_registry.json\n' "$(soviez_migration_transfer_chunks_dir "$op_id")"
}

soviez_migration_chunk_registry_init() {
  local op_id="$1" manifest_id="$2"
  local dir
  dir="$(soviez_migration_transfer_chunks_dir "$op_id")"
  mkdir -p "$dir/payloads" "$dir/assembled"
  printf '{"operation_id":"%s","manifest_id":"%s","chunks":{}}\n' "$op_id" "$manifest_id" \
    > "$(soviez_migration_chunk_registry_path "$op_id")"
}

soviez_migration_chunk_plan_file() {
  local op_id="$1" object_id="$2" category="$3" src_file="$4" chunk_size="${5:-${SOVIEZ_MIG_CHUNK_SIZE_BYTES:-67108864}}"
  local reg dir total idx offset chunk_id chunk_path digest size
  dir="$(soviez_migration_transfer_chunks_dir "$op_id")"
  mkdir -p "$dir/payloads/$object_id"
  reg="$(soviez_migration_chunk_registry_path "$op_id")"
  [[ -f "$reg" ]] || soviez_migration_chunk_registry_init "$op_id" ""
  total="$(wc -c < "$src_file" | tr -d ' ')"
  idx=0
  offset=0
  while [[ "$offset" -lt "$total" ]]; do
    size="$chunk_size"
    if (( offset + size > total )); then
      size=$(( total - offset ))
    fi
    chunk_id="${object_id}-$(printf '%06d' "$idx")"
    chunk_path="$dir/payloads/$object_id/${chunk_id}.bin"
    dd if="$src_file" of="$chunk_path" bs=1 skip="$offset" count="$size" status=none 2>/dev/null \
      || dd if="$src_file" of="$chunk_path" bs="$chunk_size" skip="$idx" count=1 2>/dev/null
    # Prefer portable python slice for correctness
    SOVIEZ_SRC="$src_file" SOVIEZ_DST="$chunk_path" SOVIEZ_OFF="$offset" SOVIEZ_SZ="$size" python3 - <<'PY'
import os
src=os.environ["SOVIEZ_SRC"]; dst=os.environ["SOVIEZ_DST"]
off=int(os.environ["SOVIEZ_OFF"]); sz=int(os.environ["SOVIEZ_SZ"])
with open(src,"rb") as f:
  f.seek(off); data=f.read(sz)
open(dst,"wb").write(data)
PY
    digest="$(openssl dgst -sha256 "$chunk_path" | awk '{print $NF}')"
    SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" SOVIEZ_OID="$object_id" SOVIEZ_CAT="$category" \
      SOVIEZ_IDX="$idx" SOVIEZ_OFF="$offset" SOVIEZ_SZ="$size" SOVIEZ_DIG="$digest" \
      SOVIEZ_OP="$op_id" SOVIEZ_PATH="$chunk_path" python3 - <<'PY'
import json, os
reg=os.environ["SOVIEZ_REG"]
d=json.load(open(reg))
chunks=d.setdefault("chunks", {})
chunks[os.environ["SOVIEZ_CID"]]={
  "chunk_id": os.environ["SOVIEZ_CID"],
  "payload_object_id": os.environ["SOVIEZ_OID"],
  "payload_category": os.environ["SOVIEZ_CAT"],
  "index": int(os.environ["SOVIEZ_IDX"]),
  "offset": int(os.environ["SOVIEZ_OFF"]),
  "expected_size": int(os.environ["SOVIEZ_SZ"]),
  "checksum": os.environ["SOVIEZ_DIG"],
  "checksum_alg": "sha256",
  "state": "planned",
  "received_bytes": 0,
  "retry_count": 0,
  "operation_id": os.environ["SOVIEZ_OP"],
  "local_path": os.environ["SOVIEZ_PATH"],
}
open(reg,"w").write(json.dumps(d, separators=(",", ":")))
PY
    offset=$(( offset + size ))
    idx=$(( idx + 1 ))
  done
  printf '{"object_id":"%s","chunk_count":%s,"total_bytes":%s}\n' "$object_id" "$idx" "$total"
}

soviez_migration_chunk_set_state() {
  local op_id="$1" chunk_id="$2" state="$3"
  local reg
  reg="$(soviez_migration_chunk_registry_path "$op_id")"
  SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" SOVIEZ_ST="$state" python3 - <<'PY'
import json, os, datetime
reg=os.environ["SOVIEZ_REG"]
d=json.load(open(reg))
c=d["chunks"][os.environ["SOVIEZ_CID"]]
c["state"]=os.environ["SOVIEZ_ST"]
c["last_attempt"]=datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
if os.environ["SOVIEZ_ST"] in ("received","verified","assembled"):
  c["received_bytes"]=c.get("expected_size") or 0
  c["verified"]= os.environ["SOVIEZ_ST"] in ("verified","assembled")
  c["finalized"]= os.environ["SOVIEZ_ST"]=="assembled"
open(reg,"w").write(json.dumps(d, separators=(",", ":")))
print(json.dumps(c, separators=(",", ":")))
PY
}

soviez_migration_chunk_verify() {
  local op_id="$1" chunk_id="$2"
  local reg path expected actual
  reg="$(soviez_migration_chunk_registry_path "$op_id")"
  path="$(SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" python3 -c 'import json,os; d=json.load(open(os.environ["SOVIEZ_REG"])); print(d["chunks"][os.environ["SOVIEZ_CID"]].get("local_path",""))')"
  expected="$(SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" python3 -c 'import json,os; d=json.load(open(os.environ["SOVIEZ_REG"])); print(d["chunks"][os.environ["SOVIEZ_CID"]].get("checksum",""))')"
  [[ -f "$path" ]] || soviez_migration_die MIGRATION_TRANSFER_CHUNK_INVALID "Missing chunk file"
  actual="$(openssl dgst -sha256 "$path" | awk '{print $NF}')"
  [[ "$actual" == "$expected" ]] || \
    soviez_migration_die MIGRATION_TRANSFER_CHUNK_CHECKSUM_MISMATCH "Chunk checksum mismatch: $chunk_id"
  soviez_migration_chunk_set_state "$op_id" "$chunk_id" verified >/dev/null
  printf '{"chunk_id":"%s","state":"verified","sha256":"%s"}\n' "$chunk_id" "$actual"
}

soviez_migration_chunk_assemble_object() {
  local op_id="$1" object_id="$2" dest_file="$3"
  local reg dir
  reg="$(soviez_migration_chunk_registry_path "$op_id")"
  dir="$(soviez_migration_transfer_chunks_dir "$op_id")"
  mkdir -p "$(dirname "$dest_file")"
  SOVIEZ_REG="$reg" SOVIEZ_OID="$object_id" SOVIEZ_DST="$dest_file" python3 - <<'PY'
import json, os
d=json.load(open(os.environ["SOVIEZ_REG"]))
oid=os.environ["SOVIEZ_OID"]
chunks=[c for c in d.get("chunks",{}).values() if c.get("payload_object_id")==oid]
chunks.sort(key=lambda c: int(c.get("index") or 0))
missing=[c["chunk_id"] for c in chunks if c.get("state") not in ("verified","assembled")]
if missing:
  raise SystemExit("MISSING:"+ ",".join(missing))
with open(os.environ["SOVIEZ_DST"],"wb") as out:
  for c in chunks:
    with open(c["local_path"],"rb") as f:
      out.write(f.read())
print(len(chunks))
PY
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    soviez_migration_die MIGRATION_CHUNK_MISMATCH "Cannot assemble $object_id — unverified chunks"
  fi
  # Mark assembled
  SOVIEZ_REG="$reg" SOVIEZ_OID="$object_id" python3 - <<'PY'
import json, os
reg=os.environ["SOVIEZ_REG"]; oid=os.environ["SOVIEZ_OID"]
d=json.load(open(reg))
for c in d.get("chunks",{}).values():
  if c.get("payload_object_id")==oid and c.get("state")=="verified":
    c["state"]="assembled"; c["finalized"]=True
open(reg,"w").write(json.dumps(d, separators=(",", ":")))
PY
  printf '{"object_id":"%s","state":"assembled","path":"%s"}\n' "$object_id" "$dest_file"
}

soviez_migration_chunk_transfer_all() {
  local op_id="$1" profile="${2:-balanced}"
  local reg chunk_id path
  reg="$(soviez_migration_chunk_registry_path "$op_id")"
  SOVIEZ_REG="$reg" python3 -c 'import json,os; d=json.load(open(os.environ["SOVIEZ_REG"])); print("\n".join(d.get("chunks",{}).keys()))' \
  | while read -r chunk_id; do
      [[ -n "$chunk_id" ]] || continue
      path="$(SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" python3 -c 'import json,os; print(json.load(open(os.environ["SOVIEZ_REG"]))["chunks"][os.environ["SOVIEZ_CID"]]["local_path"])')"
      state="$(SOVIEZ_REG="$reg" SOVIEZ_CID="$chunk_id" python3 -c 'import json,os; print(json.load(open(os.environ["SOVIEZ_REG"]))["chunks"][os.environ["SOVIEZ_CID"]].get("state",""))')"
      [[ "$state" == "assembled" || "$state" == "verified" ]] && continue
      soviez_migration_chunk_set_state "$op_id" "$chunk_id" receiving >/dev/null
      soviez_migration_channel_put "$op_id" "$chunk_id" "$path" >/dev/null
      soviez_migration_chunk_set_state "$op_id" "$chunk_id" received >/dev/null
      soviez_migration_chunk_verify "$op_id" "$chunk_id" >/dev/null
      soviez_migration_bandwidth_profile_delay "$profile"
    done
  printf '{"operation_id":"%s","status":"chunks_transferred"}\n' "$op_id"
}
