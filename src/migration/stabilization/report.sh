# shellcheck shell=bash

soviez_migration_p22_stabilization_write_report() {
  local report_id="$1" cutover_id="$2" auth_id="$3" status="$4" samples_file="$5"
  local out_dir out_file
  out_dir="$(soviez_migration_p22_stab_dir "$report_id")"
  mkdir -p "$out_dir"
  out_file="$out_dir/report.json"
  SOVIEZ_OUT="$out_file" SOVIEZ_RID="$report_id" SOVIEZ_CID="$cutover_id" \
  SOVIEZ_AID="$auth_id" SOVIEZ_ST="$status" SOVIEZ_SAMPLES="$samples_file" \
  SOVIEZ_CS="$(soviez_migration_p22_clock_source)" \
  SOVIEZ_DUR="${SOVIEZ_MIG_P22_STABILIZATION_SECONDS}" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os
samples = []
try:
  with open(os.environ["SOVIEZ_SAMPLES"]) as f:
    for line in f:
      line=line.strip()
      if line:
        samples.append(json.loads(line))
except Exception:
  samples = []
body = {
  "schema": "soviez.migration_stabilization.v1",
  "report_id": os.environ["SOVIEZ_RID"],
  "cutover_id": os.environ["SOVIEZ_CID"],
  "authorization_id": os.environ["SOVIEZ_AID"],
  "stabilization_status": os.environ["SOVIEZ_ST"],
  "required_duration_seconds": int(os.environ["SOVIEZ_DUR"]),
  "clock_source": os.environ["SOVIEZ_CS"],
  "sample_count": len(samples),
  "samples": samples,
  "purges_source": False,
  "archives_source": False,
  "created_at": os.environ["SOVIEZ_NOW"],
  "signer": "soviez-p22",
}
open(os.environ["SOVIEZ_OUT"], "w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$out_file"
  cat "$out_file"
}
