# shellcheck shell=bash

soviez_migration_phase23_readiness_write_report() {
  local report_id="$1" validation_json="$2"
  local out_dir out
  out_dir="$(soviez_migration_p22_phase23_dir "$report_id")"
  mkdir -p "$out_dir"
  out="$out_dir/report.json"
  SOVIEZ_OUT="$out" SOVIEZ_RID="$report_id" SOVIEZ_VAL="$validation_json" \
  SOVIEZ_TTL="${SOVIEZ_MIG_P22_PHASE23_TTL_SECONDS}" \
  SOVIEZ_FP="${SOVIEZ_MIG_P22_DRIFT_FINGERPRINT:-stable}" \
  SOVIEZ_NOW="$(soviez_migration_p22_now_iso)" python3 - <<'PY'
import json, os, datetime
val=json.loads(os.environ["SOVIEZ_VAL"])
ttl=int(os.environ["SOVIEZ_TTL"])
exp=(datetime.datetime.utcnow()+datetime.timedelta(seconds=ttl)).strftime("%Y-%m-%dT%H:%M:%SZ")
body={
  "schema":"soviez.migration_phase23_readiness.v1",
  "report_id": os.environ["SOVIEZ_RID"],
  "readiness_status": val["readiness_status"],
  "archive_operation_id": val.get("archive_operation_id"),
  "source_id": val.get("source_id"),
  "blockers": val.get("blockers",[]),
  "warnings": val.get("warnings",[]),
  "implements_offline_bundles": False,
  "implements_purge": False,
  "drift_fingerprint": os.environ["SOVIEZ_FP"],
  "created_at": os.environ["SOVIEZ_NOW"],
  "expires_at": exp,
  "signer": "soviez-p22",
}
open(os.environ["SOVIEZ_OUT"],"w").write(json.dumps(body, separators=(",", ":")))
PY
  soviez_migration_sign_object_file "$out"
  cat "$out"
}
