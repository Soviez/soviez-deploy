#!/usr/bin/env python3
"""Phase 23 evidence finalizer — atomic writes, fail-fast, no false PASS.

Usage:
  phase23_evidence_finalizer.py \
    --evidence-dir DIR \
    --run-all-exit N \
    --auth-exit N \
    --artifact PATH \
    --version VER \
    --ok-count N \
    --fail-count N \
    --ledger PATH \
    [--prior-log PATH ...]

Exit codes:
  0 — evidence written; aggregate certification PASS (both exits 0, fails=0)
  1 — evidence written; aggregate certification FAIL
  2 — finalizer input validation failure (no authoritative overwrite)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class FinalizerError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def require(cond: bool, code: str, message: str) -> None:
    if not cond:
        raise FinalizerError(code, message)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=str(path.parent),
    )
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except Exception:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Phase 23 evidence finalizer")
    p.add_argument("--evidence-dir", required=True)
    p.add_argument("--run-all-exit", required=True, type=int)
    p.add_argument("--auth-exit", required=True, type=int)
    p.add_argument("--artifact", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--ok-count", required=True, type=int)
    p.add_argument("--fail-count", required=True, type=int)
    p.add_argument("--ledger", required=True)
    p.add_argument("--prior-log", action="append", default=[])
    p.add_argument("--force-partial", action="store_true")
    return p.parse_args(argv)


def validate(args: argparse.Namespace) -> tuple[Path, str]:
    evidence = Path(args.evidence_dir)
    require(evidence.exists() and evidence.is_dir(), "EVIDENCE_DIR_MISSING", f"missing {evidence}")
    artifact = Path(args.artifact)
    require(artifact.is_file(), "ARTIFACT_MISSING", f"missing artifact {artifact}")
    require(args.version.strip() != "", "VERSION_MISSING", "version empty")
    require(args.ok_count >= 0, "OK_COUNT_INVALID", "ok-count must be >= 0")
    require(args.fail_count >= 0, "FAIL_COUNT_INVALID", "fail-count must be >= 0")
    require(args.ok_count + args.fail_count > 0, "ZERO_TESTS", "ok+fail counts are zero")
    ledger = Path(args.ledger)
    require(ledger.is_file(), "LEDGER_MISSING", f"missing ledger {ledger}")
    digest = sha256_file(artifact)
    require(bool(SHA256_RE.match(digest)), "SHA_MALFORMED", f"bad digest {digest}")
    return artifact, digest


def decide_verdict(args: argparse.Namespace) -> tuple[str, int, str]:
    """Return (verdict, aggregate_exit, progress_note)."""
    if args.force_partial:
        return (
            "PARTIAL — PHASE 23 OFFLINE UPDATE BUNDLES IMPLEMENTED; FULL CERTIFICATION INCOMPLETE",
            1,
            "98%",
        )
    if args.run_all_exit == 0 and args.auth_exit == 0 and args.fail_count == 0:
        return (
            "PASS — PHASE 23 OFFLINE UPDATE BUNDLES COMPLETE",
            0,
            "99%",
        )
    return (
        "PARTIAL — PHASE 23 OFFLINE UPDATE BUNDLES IMPLEMENTED; FULL CERTIFICATION INCOMPLETE",
        1,
        "98%",
    )


def write_reports(
    evidence: Path,
    args: argparse.Namespace,
    digest: str,
    verdict: str,
    agg: int,
    progress: str,
) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    prior = "\n".join(f"- `{p}`" for p in args.prior_log) or "- (none provided)"

    final = f"""# FINAL_REPORT — Phase 23 Offline Update Bundles

## Verdict
**{verdict}**

Progress: **{progress}**  
Installer: **{args.version}**  
Full SHA256: `{digest}`  
Aggregate exit: `{agg}`  
Generated: {now}  
Phase 24: **UNAUTHORIZED**

## Authoritative results
- tests/run_all.sh exit: `{args.run_all_exit}`
- phase23_authoritative_certification exit: `{args.auth_exit}`
- ok_count: `{args.ok_count}`
- fail_count: `{args.fail_count}`
- failure ledger: `{args.ledger}`

## Prior failed-run logs preserved
{prior}

## Confirmations
- No commit/push/deploy/publish
- No live customer systems/data changed
- No live bundle published
- Frozen SaaS UI unmodified
"""

    tests = f"""# TEST_RESULTS — Phase 23

timestamp_utc: {now}
run_all_exit: {args.run_all_exit}
auth_exit: {args.auth_exit}
ok_count: {args.ok_count}
fail_count: {args.fail_count}
aggregate_exit: {agg}
verdict: {verdict}
ledger: {args.ledger}
"""

    build = f"""# BUILD_ARTIFACT

Version: {args.version}
SHA256: {digest}
Artifact: {args.artifact}
Generated: {now}
"""

    meta = {
        "verdict": verdict,
        "aggregate_exit": agg,
        "progress": progress,
        "version": args.version,
        "sha256": digest,
        "run_all_exit": args.run_all_exit,
        "auth_exit": args.auth_exit,
        "ok_count": args.ok_count,
        "fail_count": args.fail_count,
        "generated_utc": now,
    }

    # Consistency gate: never write PASS if exits nonzero
    if "PASS — PHASE 23" in verdict:
        require(args.run_all_exit == 0, "VERDICT_MISMATCH", "PASS with run_all nonzero")
        require(args.auth_exit == 0, "VERDICT_MISMATCH", "PASS with auth nonzero")
        require(args.fail_count == 0, "VERDICT_MISMATCH", "PASS with fail_count>0")
        require(agg == 0, "VERDICT_MISMATCH", "PASS with aggregate nonzero")

    atomic_write(evidence / "FINAL_REPORT.md", final)
    atomic_write(evidence / "TEST_RESULTS.md", tests)
    atomic_write(evidence / "BUILD_ARTIFACT.md", build)
    atomic_write(evidence / "FINALIZER_META.json", json.dumps(meta, indent=2) + "\n")


def main(argv: list[str] | None = None) -> int:
    try:
        args = parse_args(argv)
        _artifact, digest = validate(args)
        verdict, agg, progress = decide_verdict(args)
        write_reports(Path(args.evidence_dir), args, digest, verdict, agg, progress)
        print(json.dumps({"ok": True, "verdict": verdict, "aggregate_exit": agg, "sha256": digest}))
        return agg
    except FinalizerError as e:
        print(json.dumps({"ok": False, "code": e.code, "error": e.message}), file=sys.stderr)
        return 2
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"ok": False, "code": "FINALIZER_CRASH", "error": str(e)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
